# frozen_string_literal: true

# Where this project's observations may come from on iNaturalist, and
# what MO may do about them (#5416). Rendered by
# `Projects::ExternalSourcesController#index`.
module Views::Controllers::Projects::ExternalSources
  class Form < ::Components::ApplicationForm
    prop :project, ::Project

    def initialize(model, **attrs)
      super(model, turbo: true, **attrs)
    end

    def view_template
      super do
        render_source_fields
        render_action_fields
        render_import_limit_field if in_admin_mode?
        submit(:save.ti, class: "mt-3")
      end
    end

    private

    def render_source_fields
      text_field(:remote_project_id,
                 label: :project_sources_remote_project_id.l,
                 help: :project_sources_remote_project_id_help.t)
      checkbox_field(:use_criteria,
                     label: :project_sources_use_criteria.l,
                     help: :project_sources_use_criteria_help.t,
                     wrap_class: "mt-3")
    end

    def render_action_fields
      checkbox_field(:alerting, label: :project_sources_alerting.l,
                                wrap_class: "mt-3")
      checkbox_field(:importing, label: :project_sources_importing.l)
    end

    def render_import_limit_field
      number_field(:import_limit,
                   label: :project_sources_import_limit.l,
                   help: :project_sources_import_limit_help.t,
                   inline: true, min: 1, wrap_class: "mt-3")
    end

    def form_action
      if model.persisted?
        project_external_source_path(project_id: @project.id, id: model.id)
      else
        project_external_sources_path(project_id: @project.id)
      end
    end
  end
end
