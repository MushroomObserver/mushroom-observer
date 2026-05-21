# frozen_string_literal: true

# Phlex Superform for the SpeciesList create/edit page.
# Replaces app/views/controllers/species_lists/_form.html.erb plus the
# species_lists/form/_fields_for_project.erb sub-partial.
#
# Preserves the existing controller contract exactly:
# - SpeciesList attributes posted as `species_list[title]`, `[notes]`,
#   `[when(1i)]`/`[(2i)]`/`[(3i)]`, `[place_name]` — handled by
#   Superform's namespace.
# - Optional `clone_id` posted at the top level (NOT under
#   `species_list[...]`) via the String-keyed `hidden_field`. The
#   controller reads `params[:clone_id]`.
# - Project membership posted as `species_list[project_ids][]=<id>`
#   (Rails-idiomatic has_many-through wire shape, via Superform's
#   array-mode CheckboxField). The controller's `update_projects`
#   walks `@user.projects_member` and toggles each project based on
#   whether its id is in the submitted array; non-member projects the
#   SL belongs to are preserved by omission (disabled checkboxes don't
#   submit per HTML spec, and the iteration excludes them anyway).
class Components::SpeciesListForm < Components::ApplicationForm
  # Controller-passed render state is bundled into the `**state` splat
  # so the init stays under Metrics/ParameterLists. Callers still pass
  # each piece as a named kwarg (projects:, dubious_where_reasons:,
  # clone_id:, submitted_project_ids:) — the splat just collects them.
  #
  # Checkedness for project rows defaults to `model.project_ids`. On a
  # failure-reload the controller passes `submitted_project_ids:` (the
  # user's just-submitted array) — used in preference to the model so
  # we don't have to write the user's choices to the DB just to render
  # them back (Rails' has_many-through setter would do that instantly
  # on a persisted record, even though the save itself failed).
  def initialize(species_list, user:, button:, **state)
    @user = user
    @button = button
    @projects = state[:projects] || []
    @dubious_where_reasons = state[:dubious_where_reasons] || []
    @clone_id = state[:clone_id]
    @submitted_project_ids = state[:submitted_project_ids]
    super(species_list)
  end

  # Override Superform's default `helpers.url_for(action: resource_action)`
  # so the form action is derived from the model directly via explicit
  # path helpers. Two reasons:
  # - The pre-Phlex view passed `species_lists_path` / `species_list_path`
  #   explicitly. Same URL, but Superform's url_for default also tacks
  #   on whatever query params are on the current request (`q=...`,
  #   `set_source=...`), which the pre-refactor form did not.
  # - Component tests render without a routing context, so the url_for
  #   default raises `No route matches {action: "create"}`. Explicit
  #   path helpers work standalone.
  def form_action
    model.persisted? ? species_list_path(model) : species_lists_path
  end

  def view_template
    super do
      submit(@button.l, center: true)
      render_hidden_fields
      render_visible_fields
      render_project_checkboxes if @projects.any?
      submit(@button.l, center: true)
    end
  end

  private

  # `approved_where` carries the place_name the user already saw the
  # dubious-reasons feedback for; the controller skips re-validation
  # when `species_list[approved_where] == place_name`. Pre-Phlex this
  # was a top-level URL query param on the form action; as a hidden
  # field inside the form it stays under the model's namespace.
  # The Symbol `:approved_where` routes through Superform's `field()`
  # so the name comes out as `species_list[approved_where]`. The
  # controller's `permitted_species_list_args` does NOT include
  # `:approved_where`, so strong-params drops it on mass-assignment
  # (it's a transient flow-control flag, not a model attribute).
  def render_hidden_fields
    hidden_field("clone_id", value: @clone_id) if @clone_id
    hidden_field(:approved_where, value: model.place_name)
  end

  def render_visible_fields
    text_field(:title, label: "#{:form_species_lists_title.l}:")
    textarea_field(
      :notes, rows: 12,
              label: "#{:form_species_lists_list_notes.l}:",
              help: :shared_textile_help.l
    )
    date_field(:when, inline: true, label: "#{:WHEN.l}:")
    render(Components::FormLocationFeedback.new(
             dubious_where_reasons: @dubious_where_reasons,
             button: @button
           ))
    autocompleter_field(:place_name, type: :location,
                                     label: "#{:WHERE.l}:")
  end

  def render_project_checkboxes
    div(class: "form-group") do
      label(for: "project") { plain("#{:PROJECTS.t}:") }
      div(class: "help-note mr-3") do
        plain(:form_species_lists_project_help.t)
      end
      div(class: "form-group") do
        # Sentinel: ensures `species_list[project_ids]` is always
        # present in params even when every checkbox is unchecked
        # (Rack drops keys with empty arrays). The controller's
        # `compact_blank` strips this empty value.
        input(type: "hidden", name: "species_list[project_ids][]",
              value: "", autocomplete: "off")
        @projects.each { |project| render_project_checkbox(project) }
      end
    end
  end

  # One block-mode `checkbox_field(:project_ids)` per project so each
  # gets its own `<div class="checkbox"><label>` wrapper and can carry
  # its own `disabled:` flag. `cb.option(project.id)` emits
  # `<input type="checkbox" name="species_list[project_ids][]"
  # value="<id>" checked? disabled?>` — Superform's array-mode pattern.
  # Checkedness is computed against `model.project_ids` (the
  # has_many-through reader returning the current attached id array),
  # so we no longer need `@project_checks`.
  def render_project_checkbox(project)
    checkbox_field(:project_ids,
                   label: false,
                   disabled: cannot_modify_project?(project)) do |cb|
      cb.option(project.id, checked: project_checked?(project.id)) do
        whitespace
        plain(project.title)
      end
    end
  end

  def project_checked?(project_id)
    if @submitted_project_ids
      @submitted_project_ids.map(&:to_i).include?(project_id.to_i)
    else
      model.project_ids.include?(project_id)
    end
  end

  # Mirrors the pre-refactor disable condition: the species list's
  # owner can always toggle membership, but non-owners can only toggle
  # projects they're already members of.
  def cannot_modify_project?(project)
    model.user_id != @user.id && !project.member?(@user)
  end
end
