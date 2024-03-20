# frozen_string_literal: true

module Web::Users
  class SessionsController < BaseController
    layout "web/guest"

    before_action :authenticate_user!, except: %i[create]

    def create
      user = User.authenticate_by(email: user_params[:email], password: user_params[:password])

      if user
        sign_in(user)

        redirect_to web_tasks_incomplete_path, notice: "You have successfully signed in!"
      else
        flash.now[:alert] = "Invalid email or password"

        user = User.new(email: user_params[:email])

        render("web/guest/sessions/new", status: :unprocessable_entity, locals: {user:})
      end
    end

    def destroy
      sign_out(current_user)

      redirect_to web_guests_sign_in_path, notice: "You have successfully signed out!"
    end

    private

    def user_params
      params.require(:user).permit(:email, :password)
    end
  end
end
