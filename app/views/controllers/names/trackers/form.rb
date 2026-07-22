# frozen_string_literal: true

# Form for creating or updating a name tracker. Rendered by
# `Names::TrackersController#{new,edit}`. Allows users to
# enable/disable tracking for a name and configure email
# notification templates.
module Views::Controllers::Names::Trackers
  class Form < ::Components::ApplicationForm
    def initialize(model, note_template: nil, **)
      @note_template = note_template
      super(model, **)
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
      checkbox_field(:note_template_enabled,
                     label: :email_tracking_note,
                     wrap_class: "mt-5")

      Help(class: "mt-2 mb-5",
           content: :email_tracking_note_help.t)

      textarea_field(:note_template,
                     rows: 16,
                     cols: 80,
                     value: @note_template,
                     data: { autofocus: true },
                     id: "name_tracker_note_template")
      br
    end

    def form_action
      action = model.persisted? ? :update : :create
      url_for(controller: "names/trackers", action: action, id: model.name.id,
              only_path: true)
    end
  end
end
