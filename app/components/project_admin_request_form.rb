# frozen_string_literal: true

# Form for requesting project admin access
class Components::ProjectAdminRequestForm < Components::ApplicationForm
  def view_template
    :admin_request_note.tp

    text_field(:subject, label: "#{:request_subject.t}:",
                         data: { autofocus: true })

    textarea_field(:content, label: "#{:request_message.t}:", rows: 5)

    submit(:SEND.l, center: true)
  end

  # Override to use :email scope
  def key
    :email
  end
end
