# frozen_string_literal: true

# Action template for `AccountController#welcome` — shown after a
# successful signup verification. Page title plus a textile-rendered
# welcome note + logout button for logged-in users, or a "no user
# yet" textile note for anonymous viewers.
#
module Views::Controllers::Account
  class Welcome < Views::FullPageBase
    def view_template
      add_page_title(welcome_title)
      if current_user
        trusted_html(:welcome_note.tp)
        render(Components::CrudButton::Post.new(
                 name: :app_logout.t,
                 target: account_logout_path,
                 id: "nav_user_logout_link"
               ))
      else
        trusted_html(:welcome_no_user_note.tp)
      end
    end

    private

    def welcome_title
      return :welcome_no_user_title.t unless current_user

      :email_welcome.t(user: current_user.legal_name)
    end
  end
end
