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
        render_logout_button
      else
        trusted_html(:welcome_no_user_note.tp)
      end
    end

    private

    def welcome_title
      return :welcome_no_user_title.t unless current_user

      :email_welcome.t(user: current_user.legal_name)
    end

    # Logging out changes the session's theme/asset state, so Turbo
    # Drive's head-merging on the redirected page can corrupt
    # stylesheets. Source everything from `Tab::UserNav::Logout`
    # (which already opts out of Turbo for this reason) instead of
    # re-typing the title/path/opt-out — this call site was
    # previously missing the Turbo opt-out entirely.
    def render_logout_button
      tab = Tab::UserNav::Logout.new
      Button(
        type: :post,
        name: tab.title,
        target: tab.path,
        class: tab.html_options[:class],
        data: tab.html_options[:data]
      )
    end
  end
end
