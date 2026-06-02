# frozen_string_literal: true

# "Your interests" interests-page link. Same path as
# `ShowNotifications` but different label for the user-nav /
# sidebar context.
class Tab::Account::ShowInterests < Tab::Base
  def title
    :app_your_interests.t
  end

  def path
    interests_path
  end
end
