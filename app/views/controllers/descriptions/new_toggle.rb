# frozen_string_literal: true

# Radio-gated switch between the main description form and the
# project-draft picker on `names/descriptions#new` /
# `locations/descriptions#new`. The radio is a plain UI toggle, not
# bound to either form -- it just shows/hides one Bootstrap collapse
# panel per choice, via the shared `collapse-switch` Stimulus
# controller (see `Components::Form::RadioCollapse` for the same
# mechanism used with a model-bound radio).
#
# When `NewDraftForm` has nothing to offer (already locked to a
# confirmed project, or the user has no projects to draft for), the
# radio and picker are omitted -- just the main form, same as before
# this toggle existed.
module Views::Controllers::Descriptions
  class NewToggle < Views::Base
    prop :target, _Union(::Location, ::Name)
    prop :description, ::Description
    prop :user, _Nilable(::User), default: nil
    prop :licenses, _Array(_Tuple(String, Integer)), default: -> { [] }
    prop :project, _Nilable(::Project), default: nil
    prop :project_chosen, _Boolean, default: false

    def view_template
      draft_form = build_draft_form
      # `render?` depends on view-context helpers (in_admin_mode?)
      # that only attach once Phlex has run the component through a
      # render call -- capture that render first, so the bare
      # `render?` call below (deciding whether to show the toggle) is
      # safe, and reuse the captured output as the "yes" panel.
      draft_html = capture { render(draft_form) }

      if draft_form.render?
        render_toggle(draft_html)
      else
        render(build_main_form)
      end
    end

    private

    def build_draft_form
      Components::Description::NewDraftForm.new(
        target: @target, project: @project, project_chosen: @project_chosen
      )
    end

    def build_main_form
      Views::Controllers::Descriptions::Form.new(
        @description, licenses: @licenses, user: @user, turbo: true
      )
    end

    def render_toggle(draft_html)
      div(data: { controller: "collapse-switch" }) do
        render_radios
        render_panel("no") { render(build_main_form) }
        render_panel("yes") { trusted_html(draft_html) }
      end
    end

    def render_radios
      div(class: "form-group") do
        label(class: "mr-3") do
          plain(append_colon(:show_description_new_draft_toggle.l))
        end
        render(toggle_radio_field)
      end
    end

    # Unnamespaced FieldProxy -- name="is_project_draft" -- since this
    # radio belongs to neither form; "no" is the default checked
    # value. `collapse-switch` reads the checked radio's value
    # directly, so no field binding is needed beyond that.
    def toggle_radio_field
      proxy = Components::ApplicationForm::FieldProxy.new(
        nil, "is_project_draft", "no"
      )
      Components::ApplicationForm::RadioField.new(
        proxy, ["no", :nope.ti], ["yes", :yep.ti],
        wrapper_options: { wrap_class: "d-inline-block mr-3" },
        data: { action: "change->collapse-switch#switch" }
      )
    end

    def render_panel(type, &block)
      Collapsible(expanded: type == "no",
                  data: { collapse_switch_target: "panel",
                          collapse_switch_type: type }, &block)
    end
  end
end
