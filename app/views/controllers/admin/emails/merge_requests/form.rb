# frozen_string_literal: true

module Views::Controllers::Admin::Emails::MergeRequests
  # Form for submitting a merge request email to admins. Rendered by
  # the admin/emails/merge_requests controller's `new.erb`. Allows
  # users to request merging two objects (e.g., names or locations).
  class Form < ::Components::ApplicationForm
    # rubocop:disable Metrics/ParameterLists
    def initialize(model, old_obj:, new_obj:, model_class:, user: nil, **)
      @old_obj = old_obj
      @new_obj = new_obj
      @model_class = model_class
      @user = user
      super(model, **)
    end
    # rubocop:enable Metrics/ParameterLists

    def view_template
      super do
        p { :email_merge_request_help.tp(type: @model_class.type_tag) }
        render_object_fields
        render_message_field
        submit(:SEND.l, center: true)
      end
    end

    private

    def render_object_fields
      static_field(:old_obj, label: type_label,
                             value: viewer_aware_format_name(@old_obj),
                             inline: true)
      static_field(:new_obj, label: type_label,
                             value: viewer_aware_format_name(@new_obj),
                             inline: true)
    end

    # `Components::ApplicationForm` doesn't include the shared
    # `viewer_aware_unique_format_name` helper (Components::Base).
    def viewer_aware_format_name(obj)
      obj.unique_format_name(@user).t
    end

    def render_message_field
      textarea_field(:message, label: :Notes, rows: 10,
                               value: "", data: { autofocus: true })
    end

    def type_label
      @model_class.type_tag.to_s.upcase.to_sym
    end

    def form_action
      url_for(
        action: :create,
        type: @model_class.name,
        old_id: @old_obj.id,
        new_id: @new_obj.id
      )
    end
  end
end
