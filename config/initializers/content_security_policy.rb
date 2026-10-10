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
