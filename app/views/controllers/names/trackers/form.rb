# frozen_string_literal: true

# Form for creating or updating a name tracker. Rendered by
# `Names::TrackersController#{new,edit}`. Allows users to
# enable/disable tracking for a name and configure email
# notification templates.
module Views::Controllers::Names::Trackers
  class Form < ::Components::ApplicationForm
    prop :note_template, _Nilable(String), default: nil

    def view_template
      super do
        render_tracker_fields
        render_submit_buttons
      end
    end

    private

    def render_submit_buttons
      div(class: "text-center my-3") do
        if model.persisted?
          submit(:update.ti)
          whitespace
          submit(:disable.ti)
        else
          submit(:enable.ti)
        end
      end
    end

    def render_tracker_fields
      render_note_template_checkbox
      render_note_template_fields
    end

    def render_note_template_checkbox
      render(Components::Form::CheckboxCollapse.new(
               form: self,
               field: :note_template_enabled,
               target_id: "note_template_fields",
               label: :email_tracking_note,
               expanded: note_template_enabled?,
               attributes: {
                 wrap_class: "mb-3",
                 help: :email_tracking_note_help.t
               }
             ))
    end

    def render_note_template_fields
      Collapsible(id: "note_template_fields",
                  expanded: note_template_enabled?) do
        textarea_field(:note_template,
                       rows: 16,
                       cols: 80,
                       value: @note_template,
                       data: { autofocus: true },
                       id: "name_tracker_note_template")
      end
    end

    # A new tracker gets a default template filled in for convenience,
    # but that's not consent to send it -- only an explicitly-enabled
    # (persisted, or just-submitted-and-reloaded) tracker starts
    # checked/expanded.
    def note_template_enabled?
      model.note_template_enabled == true
    end

    def form_action
      action = model.persisted? ? :update : :create
      url_for(controller: "names/trackers", action: action, id: model.name.id,
              only_path: true)
    end
  end
end
