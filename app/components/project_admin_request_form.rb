# frozen_string_literal: true

# Form for requesting project admin access
class Components::ProjectAdminRequestForm < Components::ApplicationForm
  def view_template
    raw(:admin_request_note.tp) # rubocop:disable Rails/OutputSafety
    render_subject_field
    render_content_field
    submit(:SEND.l, center: true)
  end

  # Override to use :email scope
  def key
    :email
  end

  private

  def render_subject_field
    text_field(:subject, label: "#{:request_subject.t}:", wrap_class: "mt-3",
                         data: { autofocus: true })
  end

  def render_content_field
    textarea_field(:content, label: "#{:request_message.t}:", rows: 5)
  end
end
