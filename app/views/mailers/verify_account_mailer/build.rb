# frozen_string_literal: true

module Views::Mailers::VerifyAccountMailer
  # Email sent to verify user's email. Its intro is a single
  # translated sentence with an embedded link — a placeholder token
  # ("xxx") is interpolated by `.tp`, then swapped for a real `<a>`
  # tag via `splice_html`, matching the original ERB's
  # `intro.gsub!(/xxx/, link_to(url, url))` approach.
  class Build < Views::Mailers::Base
    prop :subject, ::String
    prop :receiver, ::User

    private

    def verify_url
      "#{MO.http_domain}/account/verify/#{@receiver.id}" \
        "?auth_code=#{@receiver.auth_code}"
    end

    def link
      capture { link_to(verify_url, verify_url) }
    end

    def intro
      base = :email_verify_intro.tp(user: @receiver.login, link: "xxx")
      splice_html(base, /xxx/, link)
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
