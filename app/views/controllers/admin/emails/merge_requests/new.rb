# frozen_string_literal: true

module Views::Controllers::Admin::Emails::MergeRequests
  # Email-the-webmaster-to-merge-two-objects page. Wrapper that
  # sets the page title + context nav and renders the Form.
  class New < Views::Base
    prop :model, ::Class
    prop :old_obj, _Any
    prop :new_obj, _Any

    def view_template
      add_page_title(:email_merge_request_title.t(type: @model.type_tag))
      add_context_nav(::Tab::Email::MergeRequest.new(old_obj: @old_obj))
      render(Form.new(
               ::FormObject::EmailRequest.new,
               old_obj: @old_obj,
               new_obj: @new_obj,
               model_class: @model,
               local: true
             ))
    end
  end
end
