# frozen_string_literal: true

# Form content for the project membership confirmation modal.
# Renders the intro text, project list, and Cancel/Skip/Add All
# buttons — but no modal chrome. Callers wrap this in
# `Components::Modal` with `auto_open: true` to get the auto-opening
# Bootstrap modal (see `field_slips/new.rb` and `edit.rb`).
#
# Two render modes:
#   - "create" (when `selected:` is passed) — POSTs the selection
#     state + resolution to `/occurrences` to create a new Occurrence
#     with project resolutions.
#   - "edit" (default) — PATCHes the nested projects resource on the
#     existing `@occurrence`
#     (`/occurrences/:occurrence_id/projects`, handled by
#     `Occurrences::ProjectsController#update`).
#
# Bound to `FormObject::OccurrenceProjects` (a PORO carrying
# the selection state + resolution choice). All POSTed data lives
# under the `occurrence_projects[*]` namespace except the
# source obs (`observation_id`, top-level) — which the new-form also
# posts top-level. The controller reads from either namespace via
# `occurrence_form_param` so the same code handles the initial new-
# form post (`occurrence[*]`) and the modal repost
# (`occurrence_projects[*]`).
module Views::Controllers::Occurrences::Projects
  class Form < ::Components::ApplicationForm
    def initialize(gaps:, primary:, selected: nil, occurrence: nil, **)
      @gaps = gaps
      @primary = primary
      @selected = selected
      @occurrence = occurrence
      super(build_form_object, **)
    end

    # Declares to Modal that this form renders its own `.modal-body`
    # and `.modal-footer` divs (via Modal's `:form_content` slot, added
    # in #4293) so the form tag wraps both — submit in `.modal-footer`
    # is naturally inside the form.
    def self.owns_modal_sections?
      true
    end

    # The form (Superform's default view_template) wraps both modal
    # sections. Intro + project list live in `.modal-body`; Cancel /
    # Skip / Add All live in `.modal-footer`. Hidden fields go at the
    # top of the form (next to Superform's CSRF + `_method` inputs).
    def view_template
      super do
        selected_hidden_fields if @selected
        div(class: "modal-body") do
          render_intro
          render_project_list
        end
        div(class: "modal-footer") { render_buttons }
      end
    end

    # Superform calls this to compute the `<form action=…>` URL.
    def form_action
      if @selected
        occurrences_path
      else
        occurrence_projects_path(@occurrence)
      end
    end

    private

    def build_form_object
      # `for_update: true` flips the FormObject's `persisted?` so
      # Superform emits `_method=patch` for edit mode — the nested
      # projects resource expects PATCH. Create mode stays POST.
      unless @selected
        return FormObject::OccurrenceProjects.new(for_update: true)
      end

      FormObject::OccurrenceProjects.new(
        observation_ids: @selected.map(&:id),
        primary_observation_id: @primary.id
      )
    end

    def render_intro
      p { :occurrence_resolve_projects_intro.l }
    end

    def render_project_list
      projects = @gaps[:projects]
      return unless projects&.any?

      strong { "#{:PROJECTS.l}:" }
      # `list-unstyled` drops the bullet + left padding. Each row is a
      # flex container so the id badge (button) sits inline with the
      # project-title link.
      ul(class: "list-unstyled mt-2") do
        projects.each do |project|
          li(class: "d-flex align-items-center mb-1") do
            IdBadge(object: project, extra_class: "rss-id mr-3")
            a(href: project_path(project)) { plain(project.title) }
          end
        end
      end
    end

    def cancel_path
      if @selected
        new_occurrence_path(observation_id: @selected.first.id)
      else
        occurrence_path(@occurrence)
      end
    end

    def selected_hidden_fields
      # `observation_ids[]` is multi-valued — emit one hidden input per
      # selected obs. Bound via the String path under
      # `occurrence_projects[observation_ids][]`.
      @selected.each do |obs|
        hidden_field(
          "occurrence_projects[observation_ids][]", value: obs.id
        )
      end
      # primary_observation_id is bound via the Symbol path — emits
      # `occurrence_projects[primary_observation_id]`
      # automatically from the FormObject's model_name.
      hidden_field(:primary_observation_id)
      # observation_id (source obs) is top-level, matching the new-form
      # contract. Not a field of the resolve form object.
      hidden_field("observation_id", value: @selected.first.id)
    end

    def render_buttons
      render(Components::Modal::CloseButton.new(target: cancel_path))
      whitespace
      # Skip = proceed without backfilling projects. Both controllers
      # (`OccurrencesController#create` and
      # `Occurrences::ProjectsController#update`) only act on
      # `value="add_all"`, so any other present value (here "skip") is
      # treated as "create/keep the occurrence, leave projects alone".
      submit(:SKIP.l,
             as: :button, value: "skip",
             name: "occurrence_projects[resolution]")
      whitespace
      submit(:ADD_ALL.l,
             as: :button, variant: :primary, value: "add_all",
             name: "occurrence_projects[resolution]")
    end
  end
end
