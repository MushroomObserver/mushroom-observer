# frozen_string_literal: true

# Action view for `account/preferences#no_email`. Replaces
# `account/preferences/no_email.html.erb`. Confirms that a single email
# notification type has been turned off in response to an unsubscribe
# link clicked from one of MO's outgoing emails.
module Views::Controllers::Account::Preferences
  class NoEmail < Views::Base
    prop :user, _Nilable(User)
    prop :note, _Nilable(Symbol)

    def view_template
      add_page_title(:email_welcome.t(user: @user.legal_name))

      trusted_html(@note.tp)
      trusted_html(:no_email_how_to_reenable.tp)
      trusted_html(:no_email_some_maybe_queued.tp)
    end
  end
end
