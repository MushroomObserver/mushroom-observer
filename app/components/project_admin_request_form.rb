# frozen_string_literal: true

# Form for requesting project admin access
class Components::ProjectAdminRequestForm < Components::ApplicationForm
  def initialize(model, project:, **)
    @project = project
    super(model, **)
  end

  def view_template
    raw(:admin_request_note.tp) # rubocop:disable Rails/OutputSafety
    render_subject_field
    render_message_field
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

  def render_message_field
    textarea_field(:message, label: "#{:request_message.t}:", rows: 5)
  end

  def form_action
    url_for(controller: "/projects/admin_requests", action: :create,
            project_id: @project.id, only_path: true)
  end
end
