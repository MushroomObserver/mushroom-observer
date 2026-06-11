# frozen_string_literal: true

# Action template for `AccountController#new` — the "sign up for an
# account" page. Sets the page title and renders the signup form.
# Replaces `app/views/controllers/account/new.html.erb`.
module Views::Controllers::Account
  class New < Views::Base
    prop :new_user, ::User

    def view_template
      add_page_title(:signup_title.t)
      render(Form.new(@new_user))
    end
  end
end
