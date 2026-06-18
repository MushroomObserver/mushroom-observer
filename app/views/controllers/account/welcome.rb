# frozen_string_literal: true

# Action template for `AccountController#welcome` — shown after a
# successful signup verification. Page title plus a textile-rendered
# welcome note + logout button for logged-in users, or a "no user
# yet" textile note for anonymous viewers.
#
# Replaces `app/views/controllers/account/welcome.html.erb`.
module Views::Controllers::Account
  class Welcome < Views::FullPageBase
    def view_template
      add_page_title(welcome_title)
      if current_user
        trusted_html(:welcome_note.tp)
        button_to(:app_logout.t, account_logout_path,
                  class: "btn btn-default", id: "nav_user_logout_link")
      else
        trusted_html(:welcome_no_user_note.tp)
      end
    end

    private

    # Inlined from `AccountHelper#account_welcome_title`.
    def welcome_title
      return :welcome_no_user_title.t unless current_user

      :email_welcome.t(user: current_user.legal_name)
    end
  end
end
