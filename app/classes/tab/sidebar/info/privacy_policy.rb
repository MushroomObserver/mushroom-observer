# frozen_string_literal: true

# Sidebar info nav: privacy policy.
class Tab::Sidebar::Info::PrivacyPolicy < Tab::Base
  def title
    :app_privacy_policy.t
  end

  def path
    policy_privacy_path
  end
end
