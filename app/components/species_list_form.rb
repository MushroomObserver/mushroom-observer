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
# - Project membership posted as `project[id_<project.id>]=1` (per the
#   pre-refactor `fields_for(:project) { check_box_with_label(:"id_#{id}") }`
#   shape). The controller's `update_projects(spl, params[:project])`
#   walks `@projects` and toggles membership for each id. Switching to
#   Rails' `project_ids` collection setter would simplify this but
#   touches the controller's permission edge case (disabled checkboxes
#   for projects the user isn't permitted to modify); deferred to a
#   follow-up PR.
class Components::SpeciesListForm < Components::ApplicationForm
  # Controller-passed render state is bundled into the `**state` splat
  # so the init stays under Metrics/ParameterLists. Callers still pass
  # each piece as a named kwarg (projects:, project_checks:,
  # dubious_where_reasons:, clone_id:) — the splat just collects them.
  def initialize(species_list, user:, button:, **state)
    @user = user
    @button = button
    @projects = state[:projects] || []
    @project_checks = state[:project_checks] || {}
    @dubious_where_reasons = state[:dubious_where_reasons] || []
    @clone_id = state[:clone_id]
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
        @projects.each { |project| render_project_checkbox(project) }
      end
    end
  end

  # Each project checkbox lives outside the model's namespace — posted
  # as `project[id_<id>]=1/0` (not `species_list[project_ids][]=<id>`).
  # `FieldProxy.new("project", :"id_<id>", current_value)` gives a
  # CheckboxField input with the right `name=` / `id=` derived via
  # `dom.name` / `dom.id`. The hidden sidecar carries the "0" for
  # unchecked rows so `params[:project]["id_<id>"]` is always present
  # for the controller's `checks["id_#{p.id}"] == "1"` check.
  #
  # `checked_value: "1"` is load-bearing. MO's CheckboxField only
  # routes through the string-compare `checked = field.value.to_s ==
  # checked_value.to_s` when `checked_value:` is passed explicitly.
  # Without it, Superform's parent Checkbox emits `checked: field.value`
  # directly — and `"0"` is truthy in Ruby, so the unchecked rows
  # would render with a `checked` attribute. Setting `checked_value`
  # forces MO's correct boolean recomputation.
  def render_project_checkbox(project)
    proxy = Components::ApplicationForm::FieldProxy.new(
      "project", :"id_#{project.id}",
      @project_checks[project.id] ? "1" : "0"
    )
    render(Components::ApplicationForm::CheckboxField.new(
             proxy,
             checked_value: "1",
             disabled: cannot_modify_project?(project),
             wrapper_options: { label: project.title }
           ))
  end

  # Mirrors the pre-refactor disable condition: the species list's
  # owner can always toggle membership, but non-owners can only toggle
  # projects they're already members of.
  def cannot_modify_project?(project)
    model.user_id != @user.id && !project.member?(@user)
  end
end
