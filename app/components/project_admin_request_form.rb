# frozen_string_literal: true

# Form for requesting project admin access
class Components::ProjectAdminRequestForm < Components::ApplicationForm
  def view_template
    render_note
    render_subject_field
    render_content_field
    submit(:SEND.l, center: true)
  end

  # Override to use :email scope
  def key
    :email
  end

  private

  def render_note
    render(:admin_request_note.tp)
  end

  def render_subject_field
    text_field(:subject, label: "#{:request_subject.t}:",
                         data: { autofocus: true })
  end

  def render_content_field
    textarea_field(:content, label: "#{:request_message.t}:", rows: 5)
  end
end
