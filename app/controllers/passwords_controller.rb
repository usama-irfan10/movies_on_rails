class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[edit update]

  def new
  end

  # Always answers the same way so the form can't be used to discover accounts.
  def create
    user = User.find_by(email_address: params[:email_address].to_s)
    PasswordsMailer.reset(user).deliver_later if user

    redirect_to new_session_path,
                notice: "If an account with that email address exists, password reset instructions have been sent."
  end

  def edit
  end

  def update
    password = params[:password].to_s

    if password.present? && @user.update(password:, password_confirmation: params[:password_confirmation].to_s)
      redirect_to new_session_path, notice: "Your password has been reset. Sign in with the new password."
    else
      redirect_to edit_password_path(params[:token]),
                  alert: @user.errors.full_messages.to_sentence.presence || "Enter a new password."
    end
  end

  private
    # Tokens are signed, expire after 15 minutes and stop working once the password changes.
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to new_password_path, alert: "That password reset link is invalid or has expired."
    end
end
