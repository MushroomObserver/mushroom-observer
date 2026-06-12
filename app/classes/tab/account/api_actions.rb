# frozen_string_literal: true

# Action-nav for the account api_keys pages.
class Tab::Account::APIActions < Tab::Collection
  private

  def tabs
    [Tab::Account::EditPreferences.new,
     Tab::Account::EditProfile.new]
  end
end
