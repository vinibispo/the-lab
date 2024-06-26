# frozen_string_literal: true

module Solid::Process::EventLogs::Serialization
  module Value::HashObject
    extend self

    SYMBOL_KEYS_KEY = "_sp_symbol_keys"
    WITH_INDIFFERENT_ACCESS_KEY = "_sp_hash_with_indifferent_access"

    RESERVED_KEYS = Set[
      SYMBOL_KEYS_KEY, SYMBOL_KEYS_KEY.to_sym,
      WITH_INDIFFERENT_ACCESS_KEY, WITH_INDIFFERENT_ACCESS_KEY.to_sym,
      Value::GlobalId::KEY, Value::GlobalId::KEY.to_sym,
      Value::ActiveJob::KEY, Value::ActiveJob::KEY.to_sym,
      Value::SolidModel::KEY, Value::SolidModel::KEY.to_sym
    ].freeze

    def key(arg)
      raise reserved_key_error(arg) if RESERVED_KEYS.include?(arg)

      case arg
      when ::String, ::Symbol then arg.to_s
      else raise invalid_key_error(arg)
      end
    end

    def deserialize(hash)
      return hash.with_indifferent_access if hash.delete(WITH_INDIFFERENT_ACCESS_KEY)

      symbol_keys = hash.delete(SYMBOL_KEYS_KEY)

      return hash.transform_keys { symbol_keys.include?(_1) ? _1.to_sym : _1 } if symbol_keys

      hash
    end

    private

    def reserved_key_error(arg)
      DumpError.new("Can't serialize a Hash with reserved key #{arg.inspect}")
    end

    def invalid_key_error(arg)
      message = "Only string and symbol hash keys may be serialized, but #{arg.inspect} is a #{arg.class}"

      DumpError.new(message)
    end
  end
end
