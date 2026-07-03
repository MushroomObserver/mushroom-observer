# frozen_string_literal: true

module Views::Controllers::Projects::Violations
  # Turbo-stream modal shown when a project admin clicks
  # "Add Target Location" on a violating observation row (#4304).
  # Composes Components::Modal directly with either:
  #
  #   - `:form_content` slot owned by TargetLocationForm when the
  #     obs has usable comma-suffixes — the form spans both
  #     `.modal-body` and `.modal-footer` so submit sits inside
  #     the form naturally.
  #   - A static "no usable suffixes" body + Cancel-only footer
  #     when the obs's `where` is just a country and there's
  #     nothing to pick.
  #
  # Lives under `Views::Controllers::Projects::Violations` (not
  # `Components::`) per the convention #4300 set for
  # one-controller-action modal wrappers — it isn't reusable, it's
  # the rendering of one specific controller action.
  class TargetLocationModal < Views::Base
    def initialize(project:, obs:, user:, existing_locations:)
      super()
      @project = project
      @obs = obs
      @user = user
      @existing_locations = existing_locations
    end

    def view_template
      Modal(id: TargetLocationForm.modal_id_for(@obs),
            title: :form_violations_modal_target_location_title.l,
            user: @user) do |m|
        if TargetLocationForm.applicable?(@obs)
          m.with_form_content do
            render(TargetLocationForm.new(
                     obs: @obs, project: @project,
                     existing_locations: @existing_locations
                   ))
          end
        else
          render_no_suffixes_slots(m)
        end
      end
    end

    private

    def render_no_suffixes_slots(modal)
      modal.with_body do
        p { :form_violations_modal_target_location_no_suffixes.l }
      end
      modal.with_footer do
        render(::Components::Button.new(
                 name: :CANCEL.l,
                 data: { dismiss: "modal" }
               ))
      end
    end
  end
end
