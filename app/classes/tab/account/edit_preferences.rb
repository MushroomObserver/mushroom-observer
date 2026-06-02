# frozen_string_literal: true

# "Edit account preferences" link. Introduced here ahead of the rest
# of the `account` domain conversion (next batch) because the theme
# show context-nav composes it.
class Tab::Account::EditPreferences < Tab::Base
  def title
    :prefs_link.t
  end

  def path
    edit_account_preferences_path
  end
end
