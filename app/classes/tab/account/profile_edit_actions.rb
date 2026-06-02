# frozen_string_literal: true

# Action-nav for the account profile edit form.
class Tab::Account::ProfileEditActions < Tab::Collection
  private

  def tabs
    [Tab::Account::BulkLicenseUpdater.new,
     Tab::Account::ShowNotifications.new,
     Tab::Account::EditPreferences.new,
     Tab::Account::ShowAPIKeys.new]
  end
end
