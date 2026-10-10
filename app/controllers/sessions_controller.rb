class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: "Too many attempts. Try again later." }

  def new
  end

  def create
    user = User.authenticate_by(email_address: params[:email_address].to_s, password: params[:password].to_s)

    if user
      return_to = after_authentication_url
      reset_session # drop anything an attacker could have planted before login
      start_new_session_for(user)
      redirect_to return_to
    else
      # Re-render so the email address stays filled in (keeping it out of the URL).
      @email_address = params[:email_address] if params[:email_address].is_a?(String)
      flash.now[:alert] = "Try another email address or password."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
