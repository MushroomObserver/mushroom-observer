# frozen_string_literal: true

module Views::Controllers::Admin::Emails::NameChangeRequests
  # Email-the-curators-about-a-name-change page. Wrapper for the
  # Form, with page title + context nav.
  class New < Views::FullPageBase
    prop :name, ::Name
    prop :new_name_with_icn_id, _Nilable(::String), default: nil

    def view_template
      add_page_title(:email_name_change_request_title.t)
      add_context_nav(::Tab::Email::NameChangeRequest.new(name: @name))
      render(Form.new(
               ::FormObject::EmailRequest.new,
               name: @name,
               new_name_with_icn_id: @new_name_with_icn_id,
               local: true
             ))
    end
  end
end
