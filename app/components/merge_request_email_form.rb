# frozen_string_literal: true

# Form for submitting a merge request email to admins.
# Allows users to request merging two objects (e.g., names or locations).
class Components::MergeRequestEmailForm < Components::ApplicationForm
  prop :old_obj
  prop :new_obj
  prop :model_class

  def view_template
    super do
      p { :email_merge_request_help.tp(type: @model_class.type_tag) }
      render_object_fields
      render_notes_field
      submit(:SEND.l, center: true)
    end
  end

  private

  def render_object_fields
    field(:old_obj).static(
      wrapper_options: {
        label: "#{type_label}:",
        value: @old_obj.unique_format_name.t,
        inline: true
      }
    )

    field(:new_obj).static(
      wrapper_options: {
        label: "#{type_label}:",
        value: @new_obj.unique_format_name.t,
        inline: true
      }
    )
  end

  def render_notes_field
    field(:notes).textarea(
      wrapper_options: {
        label: "#{:Notes.t}:"
      },
      rows: 10,
      value: "",
      data: { autofocus: true }
    )
  end

  def type_label
    @model_class.type_tag.to_s.upcase.to_sym.t
  end

  def form_action
    {
      action: :create,
      type: @model_class.name,
      old_id: @old_obj.id,
      new_id: @new_obj.id
    }
  end
end
