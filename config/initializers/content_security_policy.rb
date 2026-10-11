# Strict Content Security Policy: the app serves its own CSS and no inline scripts.
# In development it only reports violations (the letter_opener_web viewer uses inline code).
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src :self
    policy.style_src :self
    policy.img_src :self, :data
    policy.font_src :self
    policy.object_src :none
    policy.base_uri :self
    policy.form_action :self
    policy.frame_ancestors :none
  end

  config.content_security_policy_report_only = Rails.env.development?
end

# Swagger UI (rswag-ui, mounted at /api-docs) needs inline scripts and sends its own policy
# that allows them. Rails would add the strict policy as a second header, and browsers
# enforce both, so the app-wide policy is skipped for those paths only.
class SkipAppContentSecurityPolicy
  def initialize(app, path_prefix:)
    @app = app
    @path_prefix = path_prefix
  end

  def call(env)
    env["action_dispatch.content_security_policy"] = nil if env["PATH_INFO"].to_s.start_with?(@path_prefix)
    @app.call(env)
  end
end

Rails.application.config.middleware.insert_before ActionDispatch::ContentSecurityPolicy::Middleware,
  SkipAppContentSecurityPolicy, path_prefix: "/api-docs"
