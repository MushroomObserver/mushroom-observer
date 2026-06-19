# frozen_string_literal: true

module Views::Controllers::Admin::Emails::WebmasterQuestions
  # Ask-the-webmaster page. Wrapper that sets the page title and
  # renders the Form, passing through the reply_to / message /
  # error state the controller computes.
  class New < Views::FullPageBase
    prop :email, _Nilable(::String), default: nil
    prop :message, _Nilable(::String), default: nil
    prop :email_error, _Nilable(_Boolean), default: nil

    def view_template
      add_page_title(:ask_webmaster_title.t)
      render(Form.new(
               reply_to: @email,
               message: @message,
               email_error: @email_error,
               local: true
             ))
    end
  end
end
