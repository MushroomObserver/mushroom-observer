# frozen_string_literal: true

# Where a project's observations may come from on iNaturalist, and what
# MO may do about them (#5416). Rendered by
# `Projects::ExternalSitesController#index`, inside that site's panel.
#
# Each of the two source shapes carries what it would bring in -- the
# observations matching it that MO does not already hold -- so an admin
# can see what a setting means before turning importing on.
module Views::Controllers::Projects::ExternalSites
  class Form < ::Components::ApplicationForm
    prop :project, ::Project
    prop :candidates, ::Inat::CandidateCount::Candidates

    def initialize(model, **attrs)
      super(model, turbo: true, **attrs)
    end

    def view_template
      super do
        render_constraints_field
        render_remote_project_field
        render_candidates_line
        render_action_fields
        number_field(:import_limit,
                     label: :project_sites_import_limit.l,
                     help: :project_sites_import_limit_help.t,
                     inline: true, min: 1, wrap_class: "mt-3")
        submit(:save.ti, class: "mt-3")
      end
    end

    private

    # A project with nothing to constrain by has nothing to follow, so
    # it gets the reason rather than a checkbox that would do nothing.
    def render_constraints_field
      return Help(content: :project_sites_no_constraints.l) unless
        @project.constraints?

      checkbox_field(:use_constraints,
                     label: :project_sites_use_constraints.l,
                     help: :project_sites_use_constraints_help.t,
                     help_collapse: true)
    end

    # What the saved configuration would bring in, on a line of its own
    # below both shapes -- the number answers to the two together, and
    # follows what is stored rather than what is on screen, which is why
    # it names the button that would refresh it.
    def render_candidates_line
      text = candidates_text
      p(class: "mt-2") { text } if text
      render_over_limit
      render_unresolved(:project_sites_unresolved_names,
                        @candidates.unresolved_names)
      render_unresolved(:project_sites_unresolved_locations,
                        @candidates.unresolved_locations)
    end

    def candidates_text
      return :project_sites_unbounded.t unless @candidates.configured
      return nil unless @candidates.total

      :project_sites_candidates.t(count: @candidates.total)
    end

    def render_over_limit
      return unless @candidates.total.to_i > model.import_limit

      p(class: "mt-2") do
        :project_sites_over_limit.t(limit: model.import_limit)
      end
    end

    # A target iNat does not know is left out of the search rather than
    # guessed at, which is worth saying: it is why a count can be larger
    # than the project means.
    def render_unresolved(tag, targets)
      return if targets.blank?

      p(class: "mt-2") { tag.t(targets: targets.join(", ")) }
    end

    # Two states in one place: what the saved project resolved to, and
    # the field for naming one. The clear button swaps them back without
    # a round trip; the change saves with the rest of the form.
    def render_remote_project_field
      div(class: "mt-3", data: { controller: "remote-project" }) do
        render_remote_project_display
        render_remote_project_entry
      end
    end

    def render_remote_project_display
      div(data: { remote_project_target: "display" }, hidden: !resolved?) do
        label(for: field(:remote_project_id).dom.id) do
          plain(append_colon(:project_sites_remote_project.l))
        end
        whitespace
        render_remote_project_link
        render_clear_button
      end
    end

    def render_remote_project_link
      Link(type: :external, content: model.remote_project_name.to_s,
           path: model.remote_url.to_s)
    end

    # An anchor, not a bare <button>: the browser paints a plain button
    # its own box, and the site's other stripped buttons only escape
    # that through the form.button_to reset in _links_buttons_alerts.
    def render_clear_button
      Button(tag: :a, variant: :strip, icon: :delete, href: "#",
             role: "button", class: "text-danger ml-2",
             icon_title: :project_sites_clear_remote_project.l,
             data: { action: "remote-project#clear:prevent" })
    end

    def render_remote_project_entry
      div(data: { remote_project_target: "entry" }, hidden: resolved?) do
        text_field(:remote_project_id,
                   label: :project_sites_remote_project.l, inline: true,
                   help: :project_sites_remote_project_help.t,
                   help_collapse: true,
                   data: { remote_project_target: "input" })
      end
    end

    def render_action_fields
      checkbox_field(:alerting, label: :project_sites_alerting.l,
                                wrap_class: "mt-3")
      checkbox_field(:importing, label: :project_sites_importing.l)
    end

    def resolved?
      model.remote_project_name.present?
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
