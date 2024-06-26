# frozen_string_literal: true

module Solid::Process::EventLogs
  class Record::Listener
    include ActiveSupport::Configurable
    include ::Solid::Result::EventLogs::Listener

    config_accessor(:logger, :parameter_filter, :backtrace_cleaner)

    rails_root = Rails.root.to_s
    backtrace__cleaner = Solid::Process::BacktraceCleaner.new
    backtrace__cleaner.add_filter { |line| line.sub("#{rails_root}/", "") }

    self.logger = Rails.logger
    self.parameter_filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    self.backtrace_cleaner = backtrace__cleaner

    def on_finish(event_logs:)
      create_record_async(event_logs, caller: "on_finish")
    end

    def before_interruption(exception:, event_logs:)
      exception_data = {
        class: exception.class.name,
        message: exception.message,
        backtrace: backtrace_cleaner.clean(exception.backtrace).join("; ")
      }

      create_record_async(event_logs, exception_data: exception_data, caller: "before_interruption")
    end

    private

    def create_record_async(event_logs, exception_data: nil, caller: nil)
      Record::Executor.post { create_record(event_logs, exception_data: exception_data, caller: caller) }
    end

    def create_record(event_logs, exception_data: nil, caller: nil)
      create_record!(event_logs, exception_data: exception_data)
    rescue => e
      err = "#{e.message} (#{e.class}); Backtrace: #{e.backtrace.join(", ")}"

      logger.warn "Error on #{self.class}##{caller}: #{err}"

      nil
    end

    def create_record!(event_logs, exception_data:)
      ::Rails.error.record do
        serialized_event_logs = filter_and_serialize(event_logs)

        if exception_data
          serialized_event_logs[:category] = "error"
          serialized_event_logs[:exception_class] = exception_data[:class]
          serialized_event_logs[:exception_message] = exception_data[:message]
          serialized_event_logs[:exception_backtrace] = exception_data[:backtrace]
        end

        Record.create!(serialized_event_logs)
      end
    end

    def filter_and_serialize(event_logs)
      serialized_attributes = Serialization::Model.serialize(event_logs).attributes

      records = serialized_attributes[:records].map do
        result = _1[:result]
        result_value = parameter_filter.filter(result[:value].dup)
        result_filtered = result.merge(value: result_value)

        and_then = _1[:and_then]
        and_then_arg = parameter_filter.filter(and_then[:arg].dup) if and_then[:arg]
        and_then_filtered = and_then.merge(arg: and_then_arg) if and_then[:arg]

        _1.merge(result: result_filtered, and_then: and_then_filtered || and_then)
      end

      serialized_attributes.merge(records: records)
    end
  end
end
