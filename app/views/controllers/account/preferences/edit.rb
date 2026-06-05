# frozen_string_literal: true

# Action view for `account/preferences#edit`. Sets up the page title
# and context nav, then renders the form. The three retroactive
# image-pref triggers (vote anonymity, license, filename purge) now
# live inline next to their related selects inside the Privacy
# section of the form, rather than as a footer row outside it.
module Views::Controllers::Account::Preferences
  class Edit < Views::Base
    prop :user, _Nilable(User)
    prop :licenses, _Array(_Tuple(String, Integer)), default: -> { [] }

    def view_template
      add_page_title(:prefs_title.t)
      add_context_nav(Tab::Account::PreferencesEditActions.new)

      render(Components::AccountPreferencesForm.new(@user, licenses: @licenses))
    end
  end
end
