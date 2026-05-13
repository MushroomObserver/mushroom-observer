# frozen_string_literal: true

# Form for editing an Occurrence: change primary observation, remove
# observations, edit the primary observation's location/date inline.
#
# Uses the `Occurrence` AR model directly (same pattern as
# `ObservationForm`). `@occurrence.persisted?` is true so Superform
# auto-emits PATCH — no manual `_method=patch` override needed.
# The inline primary-obs edit fields ride under
# `occurrence[primary_observation][...]`, with Superform auto-resolving
# field values through the `primary_observation` AR association. The
# controller applies the params to the primary observation manually
# (permission check + `where`-text mirror on location change).
class Components::OccurrenceEditForm < Components::ApplicationForm
  def initialize(occurrence:, observations:, candidates:,
                 user:, **)
    @occurrence = occurrence
    @observations = observations
    @candidates = candidates
    @user = user
    super(occurrence, data: { controller: "occurrence-edit-form" }, **)
  end

  def view_template
    super do
      render_details_section
      submit(:edit_occurrence_submit.l, center: true)
      render_blank_observation_ids_hidden
      render_observation_grid
      render_candidate_section if @candidates.any?
    end
  end

  def form_action
    occurrence_path(@occurrence)
  end

  private

  # Rails idiom: a hidden blank ensures the param is present (as an
  # empty array) even when every checkbox is unchecked.
  def render_blank_observation_ids_hidden
    hidden_field("occurrence[observation_ids][]", value: "")
  end

  def render_observation_grid
    ul(
      class: "row list-unstyled mt-3",
      data: {
        controller: "matrix-table",
        action: "resize@window->matrix-table#rearrange"
      }
    ) do
      @observations.each { |obs| render_obs_box(obs) }
    end
  end

  def render_obs_box(obs)
    MatrixBox(user: @user, object: obs, votes: false) do
      block_given? ? yield : render_obs_controls(obs)
    end
  end

  def render_obs_controls(obs)
    render_include_checkbox(obs)
    render_primary_radio(obs)
    render_occurrence_warning(obs)
  end

  def render_primary_radio(obs)
    radio_field(:primary_observation_id,
                [obs.id, :create_occurrence_primary.l],
                wrap_class: "my-0",
                data: { action: "occurrence-edit-form#primarySelected" })
  end

  def render_include_checkbox(obs)
    data = { action: "occurrence-edit-form#includeToggled" }
    checkbox_field(:observation_ids,
                   label: false, wrap_class: "my-0", data: data) do |cb|
      cb.option(obs.id) { "Include" }
    end
  end

  # --- Primary-obs inline edit section ---

  def render_details_section
    locations = distinct_locations
    h4(class: "mt-4") { plain(:edit_occurrence_details_heading.l) }
    namespace(:primary_observation) do |attrs_ns|
      render_location_select(attrs_ns, locations) if locations.size > 1
      render_date_field(attrs_ns)
    end
  end

  def render_location_select(attrs_ns, locations)
    render(attrs_ns.field(:location_id).select(
             location_options(locations),
             wrapper_options: { label: :edit_occurrence_location.l }
           ))
  end

  def render_date_field(attrs_ns)
    render(attrs_ns.field(:when).date(
             wrapper_options: { label: :WHEN.l, inline: true }
           ))
  end

  # Superform expects `[value, label]`; Rails' select helper returns
  # `[label, value]`, so swap.
  def location_options(locations)
    locations.map { |name, id| [id, name] }
  end

  def distinct_locations
    seen = Set.new
    @observations.filter_map do |obs|
      loc = obs.location
      next if loc.nil? || seen.include?(loc.id)

      seen.add(loc.id)
      [loc.display_name, loc.id]
    end
  end

  # --- Candidates ---

  def render_candidate_section
    h4(class: "mt-4") { plain(:edit_occurrence_add_heading.l) }
    ul(
      class: "row list-unstyled mt-3",
      data: {
        controller: "matrix-table",
        action: "resize@window->matrix-table#rearrange"
      }
    ) do
      @candidates.each do |obs|
        render_obs_box(obs) { render_obs_controls(obs) }
      end
    end
  end

  # --- Occurrence warnings (shared by edit + candidate sections) ---

  def render_occurrence_warning(obs)
    fs = obs.field_slip
    if fs
      render_field_slip_link(fs)
    elsif obs.occurrence&.observations&.many?
      render_occurrence_link(obs)
    end
  end

  def render_field_slip_link(field_slip)
    br
    small do
      a(href: field_slip_path(field_slip)) do
        plain("Field Slip: #{field_slip.code}")
      end
    end
  end

  def render_occurrence_link(obs)
    br
    a(href: occurrence_path(obs.occurrence_id)) do
      span(class: "glyphicon glyphicon-th-large")
      plain(" ")
      plain(:in_existing_occurrence.l)
    end
  end
end
