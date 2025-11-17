# frozen_string_literal: true

# Form for creating or updating a name tracker.
# Allows users to enable/disable tracking for a name and configure
# email notification templates.
class Components::NameTrackerForm < Components::ApplicationForm
  def initialize(model, method: nil, note_template: nil, **)
    @method = method
    @note_template = note_template
    super(model, id: "name_tracker_form", **)
  end

  def view_template
    super do
      render_submit_buttons
      render_tracker_fields
    end
  end

  private

  def render_submit_buttons
    div(class: "text-center my-3") do
      if model
        submit(:UPDATE.t)
        whitespace
        submit(:DISABLE.t)
      else
        submit(:ENABLE.t)
      end
    end
  end

  def render_tracker_fields
    namespace(:name_tracker) do |builder|
      builder.field(:note_template_enabled).checkbox(
        wrapper_options: {
          label: :email_tracking_note.t,
          wrap_class: "mt-5"
        }
      )

      div(class: "help-note mt-2 mb-5") do
        :email_tracking_note_help.t
      end

      builder.field(:note_template).textarea(
        rows: 16,
        cols: 80,
        value: @note_template,
        data: { autofocus: true }
      )
      br
    end
  end

  def form_action
    url_for(controller: "names/trackers", action: :create, id: model.name.id,
            only_path: true)
  end

  protected

  def form_method
    return super unless @method

    @method.to_s.downcase == "get" ? "get" : "post"
  end
end
