# frozen_string_literal: true

# Where a project's observations may come from on iNaturalist, and what
# MO may do about them (#5416). Rendered by
# `Projects::ExternalSitesController#index`, inside that site's panel.
module Views::Controllers::Projects::ExternalSites
  class Form < ::Components::ApplicationForm
    prop :project, ::Project

    def initialize(model, **attrs)
      super(model, turbo: true, **attrs)
    end

    def view_template
      super do
        text_field(:remote_project_id,
                   label: :project_sites_remote_project.l,
                   help: :project_sites_remote_project_help.t)
        checkbox_field(:use_constraints,
                       label: :project_sites_use_constraints.l,
                       help: :project_sites_use_constraints_help.t,
                       wrap_class: "mt-3")
        render_action_fields
        number_field(:import_limit,
                     label: :project_sites_import_limit.l,
                     help: :project_sites_import_limit_help.t,
                     inline: true, min: 1, wrap_class: "mt-3")
        submit(:save.ti, class: "mt-3")
      end
    end

    private

    def render_action_fields
      checkbox_field(:alerting, label: :project_sites_alerting.l,
                                wrap_class: "mt-3")
      checkbox_field(:importing, label: :project_sites_importing.l)
    end

    def form_action
      if model.persisted?
        project_external_site_path(project_id: @project.id, id: model.id)
      else
        project_external_sites_path(project_id: @project.id)
      end
    end
  end
end
