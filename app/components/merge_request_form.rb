# frozen_string_literal: true

# Form for submitting a merge request email to admins.
# Allows users to request merging two objects (e.g., names or locations).
class Components::MergeRequestForm < Components::ApplicationForm
  def initialize(model, old_obj:, new_obj:, model_class:, **)
    @old_obj = old_obj
    @new_obj = new_obj
    @model_class = model_class
    super(model, **)
  end

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
    static_field(:old_obj, label: "#{type_label}:",
                           value: @old_obj.unique_format_name.t, inline: true)
    static_field(:new_obj, label: "#{type_label}:",
                           value: @new_obj.unique_format_name.t, inline: true)
  end

  def render_message_field
    textarea_field(:message, label: "#{:Notes.t}:", rows: 10,
                             value: "", data: { autofocus: true })
  end

  def type_label
    @model_class.type_tag.to_s.upcase.to_sym.t
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
