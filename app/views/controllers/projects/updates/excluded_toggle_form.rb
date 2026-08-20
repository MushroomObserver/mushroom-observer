# frozen_string_literal: true

module Views::Controllers::Projects::Updates
  # Autosubmitting GET checkbox that toggles whether excluded
  # observations show on a project's Updates tab.
  class ExcludedToggleForm < Views::Base
    prop :project, ::Project
    prop :show_excluded, _Boolean

    def view_template
      # Not a Components::ApplicationForm -- the only field is a
      # standalone checkbox with no model to bind (Superform's
      # form_tag/CSRF/_method machinery, and the model: prop it
      # requires, would all be unused here), so this builds a plain
      # GET form by hand, styled via FieldProxy + CheckboxField (the
      # established way to reuse ApplicationForm's field markup
      # outside a Superform-bound form).
      # rubocop:disable MO/NoHandRolledFormTag
      form(action: project_updates_path(project_id: @project.id),
           method: :get,
           class: "form-inline show-excluded-form",
           data: { turbo: "false", controller: "autosubmit",
                   autosubmit_delay_value: "0" }) do
        render_show_excluded_checkbox
      end
      # rubocop:enable MO/NoHandRolledFormTag
    end

    private

    def render_show_excluded_checkbox
      proxy = Components::ApplicationForm::FieldProxy.new(
        nil, "show_excluded"
      )
      render(Components::ApplicationForm::CheckboxField.new(
               proxy, checked: @show_excluded,
                      wrapper_options: checkbox_wrapper_options,
                      data: { action: "change->autosubmit#submit" }
             ))
    end

    def checkbox_wrapper_options
      { label: :project_updates_show_excluded.t,
        wrap_class: "checkbox-inline mb-0" }
    end
  end
end
