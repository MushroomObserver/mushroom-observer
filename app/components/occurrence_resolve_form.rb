# frozen_string_literal: true

# Form content for the project membership confirmation modal.
# Renders the intro text, project list, and Cancel/Add All buttons —
# but no modal chrome. Callers wrap this in `Components::Modal` with
# `auto_open: true` to get the auto-opening Bootstrap modal (see
# `field_slips/new.html.erb` and `edit.html.erb`).
#
# Two render modes:
#   - "create" (when `selected:` is passed) — POSTs the selected
#     `observation_ids[]` + `observation_id` + the primary observation
#     to `/occurrences` to create a new Occurrence with project
#     resolutions.
#   - "edit" (default) — POSTs to the resolve_projects action on the
#     existing `@occurrence`.
#
# Inherits `Components::ApplicationForm` (Superform) so the `<form>`
# tag, CSRF token, and `_method` hidden field are emitted
# automatically — no manual `authenticity_token_field` boilerplate.
class Components::OccurrenceResolveForm < Components::ApplicationForm
  def initialize(gaps:, primary:, selected: nil, occurrence: nil, **)
    @gaps = gaps
    @primary = primary
    @selected = selected
    @occurrence = occurrence
    # Superform requires a model. We don't bind any fields to it
    # (all this form's inputs are hidden, posted with explicit
    # `name=`), so anything callable for `dom.id` works. Use the
    # occurrence in edit mode, a placeholder Occurrence otherwise.
    super(@occurrence || Occurrence.new, **)
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
  # Add All live in `.modal-footer`. Hidden fields go at the top of
  # the form (next to Superform's CSRF + `_method` inputs).
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
      resolve_projects_occurrence_path(@occurrence)
    end
  end

  private

  def render_intro
    p { :occurrence_resolve_projects_intro.l }
  end

  def render_project_list
    projects = @gaps[:projects]
    return unless projects&.any?

    strong { :occurrence_resolve_projects_projects.l }
    # `list-unstyled` drops the bullet + left padding. Each row is a
    # flex container so the id badge (button) sits inline with the
    # project-title link.
    ul(class: "list-unstyled mt-2") do
      projects.each do |project|
        li(class: "d-flex align-items-center mb-1") do
          show_title_id_badge(project, "rss-id mr-3")
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
    # `occurrence[observation_ids][]` — the controller reads
    # `params.dig(:occurrence, :observation_ids)`. A flat
    # `observation_ids[]` here would silently break submission
    # (controller gets `nil`, treats it as an empty selection).
    @selected.each do |obs|
      hidden_field("occurrence[observation_ids][]", value: obs.id)
    end
    # `observation_id` is the source obs (top-level param), not
    # nested under `occurrence[]` — separate from the selected list.
    hidden_field("observation_id", value: @selected.first.id)
    hidden_field("occurrence[primary_observation_id]", value: @primary.id)
  end

  def render_buttons
    a(href: cancel_path, class: "btn btn-default",
      data: { dismiss: "modal" }) do
      :occurrence_resolve_projects_cancel.l
    end
    whitespace
    submit(
      :occurrence_resolve_projects_add_all.l,
      as: :button, btn_class: "btn-primary", value: "add_all",
      name: @selected ? "project_resolution" : "resolution"
    )
  end
end
