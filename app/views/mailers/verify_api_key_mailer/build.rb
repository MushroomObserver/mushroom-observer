# frozen_string_literal: true

module Views::Mailers::VerifyAPIKeyMailer
  # Email sent to verify and activate a new API key. Its intro is a
  # single translated sentence with two embedded links — same
  # placeholder-token + splice_html technique as VerifyAccountMailer.
  class Build < Views::Mailers::Base
    prop :subject, ::String
    prop :receiver, ::User
    prop :app_user, ::User
    prop :api_key, ::APIKey

    private

    def activate_url
      account_activate_api_key_url(@api_key, host: MO.http_domain)
    end

    def manager_url
      account_api_keys_url(host: MO.http_domain)
    end

    def activate_link
      capture { link_to(activate_url, activate_url) }
    end

    def manager_link
      capture { link_to(manager_url, manager_url) }
    end

    def intro
      base = :email_verify_api_key_intro.tp(
        user: @receiver.login, app_user: @app_user.login,
        app: @api_key.notes, activate_link: "xxx", manager_link: "yyy"
      )
      spliced = splice_html(base, /xxx/, activate_link)
      splice_html(spliced, /yyy/, manager_link)
    end
  end

  class Html < Build
    def view_template
      render(Views::Layouts::Mailer::Html.new(subject: @subject)) do
        trusted_html(intro)
      end
    end
  end

  class Text < Build
    def view_template
      trusted_html(intro.html_to_ascii)
    end
  end
end
