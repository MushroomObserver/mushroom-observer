# frozen_string_literal: true

# Action-nav for the account preferences edit form.
class Tab::Account::PreferencesEditActions < Tab::Collection
  private

  def tabs
    [Tab::Account::BulkLicenseUpdater.new,
     Tab::Account::ChangeImageVoteAnonymity.new,
     Tab::Account::EditProfile.new,
     Tab::Account::ShowNotifications.new,
     Tab::Account::ShowAPIKeys.new]
  end
end
