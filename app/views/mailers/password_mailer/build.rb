# frozen_string_literal: true

module Views::Mailers::PasswordMailer
  # User forgot their password. Deviates from StandardMessageBody:
  # no report_abuse footer, and the boxed content is the raw password
  # (not `.tp`-textilized, matching the original ERB which never
  # marked it html_safe either — Phlex's default `plain` escaping is
  # therefore the faithful equivalent, not `trusted_text`).
  class Build < Views::Mailers::Base
    prop :subject, ::String
    prop :receiver, ::User
    prop :password, ::String

    private

    def intro = :email_new_password_intro.l

    def handy_links
      :email_new_password_what_now.l.sub(/\n*\z/, "\n#{:email_handy_links.l}")
    end

    def links
      [[:email_links_change_prefs.t,
        "#{MO.http_domain}/account/preferences/edit/#{@receiver.id}"],
       [:email_links_latest_changes.t, MO.http_domain]]
    end
  end

  class Html < Build
    include Views::Mailers::HtmlMode

    def view_template
      render(Views::Layouts::Mailer::Html.new(subject: @subject)) do
        render_body
      end
    end

    private

    def render_body
      emit_tp(intro)
      render_message_box { plain(@password) }
      emit_tp(handy_links)
      render_links_section(links)
    end
  end

  class Text < Build
    include Views::Mailers::TextMode

    def view_template
      emit_tp(intro)
      plain("\n\n#{@password}\n\n")
      emit_tp(handy_links)
      plain("\n\n")
      render_links_section(links)
    end
  end
end
