# frozen_string_literal: true

module Views::Controllers::Admin::Emails::MergeRequests
  # Email-the-webmaster-to-merge-two-objects page. Wrapper that
  # sets the page title + context nav and renders the Form.
  class New < Views::Base
    # `@model` is the class itself (Herbarium / Location / Name);
    # `@old_obj` / `@new_obj` are instances of one of those three —
    # the only models validated as mergeable by
    # `Admin::Emails::MergeRequestsController#validate_merge_model!`.
    prop :model, ::Class
    prop :old_obj, _Union(::Herbarium, ::Location, ::Name)
    prop :new_obj, _Union(::Herbarium, ::Location, ::Name)

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
