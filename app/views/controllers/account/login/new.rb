# frozen_string_literal: true

# Action template for `Account::LoginController#new` — the login
# page. Page title + login form, followed by three "why log in"
# sections (signup invitation, spider/SEO explanation, what data
# requires login).
#
# The textile content (`:login_*.t` / `.tp`) often embeds
# `"text":url` links that the translator renders as real `<a>`
# tags; everything goes through `trusted_html` so the markup
# survives — `plain` would escape the embedded `<a>`.
module Views::Controllers::Account::Login
  class New < Views::FullPageBase
    prop :login, _Nilable(String)
    prop :remember, _Nilable(_Boolean)

    def view_template
      add_page_title(:login_please_login.t)
      render(Form.new(
               FormObject::Login.new(login: @login, remember_me: @remember),
               action: account_login_path,
               id: "account_login_form"
             ))
      render_create_account_section
      render_why_section
      render_data_without_login_section
    end

    private

    def render_create_account_section
      div do
        div(class: "h3") { trusted_html(:login_create_account_caption.tp) }
        trusted_html(:login_no_account.tp)
        plain(" (")
        trusted_html(:login_explain_login_requirement.t)
        plain(")")
      end
    end

    def render_why_section
      div do
        div(class: "h3") { trusted_html(:login_why.t) }
        div { trusted_html(:login_spiders_bad1.t) }
        br
        div { trusted_html(:login_spiders_bad2.t) }
        br
        div { trusted_html(:login_spiders_bad3.t) }
      end
    end

    def render_data_without_login_section
      div do
        div(class: "h3") do
          trusted_html(:login_data_without_login_caption.tp)
        end
        div do
          trusted_html(:login_images_without_login.tp)
          plain(" ")
          trusted_html(:login_data_without_login.tp)
        end
      end
    end
  end
end
