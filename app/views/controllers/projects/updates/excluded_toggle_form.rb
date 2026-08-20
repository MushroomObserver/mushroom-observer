# frozen_string_literal: true

module Views::Controllers::Projects::Updates
  # Autosubmitting GET checkbox that toggles whether excluded
  # observations show on a project's Updates tab.
  class ExcludedToggleForm < Components::ApplicationForm
    prop :project, ::Project

    # Accept optional model arg for ModalForm compatibility (ignored
    # -- we create our own FormObject). Pattern B: form creates
    # FormObject internally.
    def initialize(_model = nil, project:, show_excluded:, **)
      super(FormObject::ProjectExclusions.new(show: show_excluded),
            project: project, turbo: false, **)
    end

    def view_template
      super do
        checkbox_field(:show, label: :project_updates_show_excluded.t,
                              wrap_class: "checkbox-inline mb-0",
                              data: { action: "change->autosubmit#submit" })
      end
    end

    private

    # `action:`/`method:`/`class:`/`data:` are ordinary constructor
    # kwargs the base class would otherwise handle without an
    # override -- but form_action needs `project_updates_path`, a
    # Rails route helper, and Phlex-Rails raises
    # HelpersCalledBeforeRenderError if a route helper runs from
    # `initialize` (confirmed directly: moving this call into the
    # constructor throws). `form_tag` runs during rendering, after
    # helpers become available, so the route-helper call has to live
    # here, which means the whole tag has to be built here too.
    # rubocop:disable MO/NoHandRolledFormTag
    def form_tag(&block)
      form(action: form_action, method: :get, **form_attributes, &block)
    end
    # rubocop:enable MO/NoHandRolledFormTag

    def form_action
      project_updates_path(project_id: @project.id)
    end

    def form_attributes
      {
        class: "form-inline show-excluded-form",
        data: (@attributes[:data] || {}).merge(
          controller: "autosubmit", autosubmit_delay_value: "0"
        )
      }
    end

    # GET forms don't need authenticity tokens or _method fields
    def authenticity_token_field; end
    def _method_field; end
  end
end
