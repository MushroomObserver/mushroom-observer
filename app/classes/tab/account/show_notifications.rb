# frozen_string_literal: true

# "Your notifications" interests-page link. Distinct from
# `ShowInterests` in title only (different label for different
# user-facing context).
class Tab::Account::ShowNotifications < Tab::Base
  def title
    :show_user_your_notifications.t
  end

  def path
    interests_path
  end
end
