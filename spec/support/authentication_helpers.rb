module AuthenticationHelpers
  # Logs in through the real sign-in form so request specs exercise the whole flow.
  def sign_in(user = create(:user), password: user.password)
    post session_path, params: { email_address: user.email_address, password: }
    user
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
