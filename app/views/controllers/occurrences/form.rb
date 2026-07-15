# frozen_string_literal: true

module Views::Controllers::Occurrences
  # Form for creating or editing an Occurrence by selecting
  # observations. Branches on `model.persisted?` for the two flows:
  #
  # - **New** (`model.new_record?`): pass `source_obs:` +
  #   `recent_observations:`. The source obs is always-included and
  #   primary-by-default; recents are optional add-ons. Stimulus
  #   fallback strategy: "source" (revert to source if current
  #   primary gets unchecked).
  # - **Edit** (`model.persisted?`): pass `observations:` (current
  #   members) + `candidates:` (potential adds). Renders an inline
  #   primary-obs detail edit section (location + date). Stimulus
  #   fallback strategy: "first-included".
  #
  # Uses the `Occurrence` AR model directly (no separate form
  # object), same pattern as `ObservationForm`. Both `observation_ids`
  # (auto-generated via `has_many :observations`) and
  # `primary_observation_id` (a column) are addressed directly via
  # `field(:...)`.
  class Form < ::Components::ApplicationForm
    # rubocop:disable Metrics/ParameterLists
    def initialize(model:, user:,
                   source_obs: nil, recent_observations: [],
                   observations: nil, candidates: [], **)
      @source_obs = source_obs
      @recent_observations = recent_observations
      @observations = observations
      @candidates = candidates
      @user = user
      super(model, **form_options_for(model, **))
    end
    # rubocop:enable Metrics/ParameterLists

    def view_template
      if model.persisted?
        render_edit_layout
      else
        render_new_layout
      end
    end

    def form_action
      model.persisted? ? occurrence_path(model) : occurrences_path
    end

    private

    # Edit mode wires the occurrence-form Stimulus controller onto
    # the form itself so its scope spans both the members matrix and
    # the candidate matrix. New mode skips that — its single matrix
    # gets the controller wired directly (see
    # render_new_observation_grid).
    def form_options_for(model, **opts)
      return opts unless model.persisted?

      opts.merge(
        data: { controller: "occurrence-form",
                "occurrence-form-fallback-value": "first-included" }
      )
    end

    # ---------- New (create) layout ----------

    def render_new_layout
      render_source_obs_id_hidden
      render_new_observation_grid
      submit(:create_occurrence_submit.l, center: true)
    end

    # Flat `observation_id` (form context, not an Occurrence
    # attribute) so the controller can identify the source obs on
    # POST — needed for the `redirect back to
    # /occurrences/new?observation_id=X` error path.
    def render_source_obs_id_hidden
      hidden_field("observation_id", value: @source_obs.id)
    end

    def render_new_observation_grid
      all_obs = [@source_obs] + @recent_observations
      Row(
        element: :ul,
        class: "list-unstyled mt-3",
        data: {
          controller: "matrix-table occurrence-form",
          action: "resize@window->matrix-table#rearrange",
          "occurrence-form-fallback-value": "source"
        }
      ) do
        all_obs.each do |obs|
          if obs == @source_obs
            render_obs_box(obs) { render_source_controls(obs) }
          else
            render_obs_box(obs)
          end
        end
      end
    end

    # The source obs is always included — render a hidden
    # array-element so `occurrence[observation_ids][]=source.id`
    # always submits, then show the "Source" label and the (checked)
    # primary radio.
    def render_source_controls(obs)
      hidden_field("occurrence[observation_ids][]", value: obs.id)
      strong { plain(:create_occurrence_source.l) }
      render_primary_radio(obs, source: true)
    end

    # ---------- Edit (update) layout ----------

    def render_edit_layout
      render_details_section
      submit(:edit_occurrence_submit.l, center: true)
      render_blank_observation_ids_hidden
      render_edit_observation_grid
      render_candidate_section if @candidates.any?
    end

    # Rails idiom: a hidden blank ensures the param is present (as
    # an empty array) even when every checkbox is unchecked.
    def render_blank_observation_ids_hidden
      hidden_field("occurrence[observation_ids][]", value: "")
    end

    def render_edit_observation_grid
      render_matrix_ul do
        @observations.each { |obs| render_obs_box(obs) }
      end
    end

    def render_candidate_section
      h4(class: "mt-4") { plain(:edit_occurrence_add_heading.l) }
      render_matrix_ul do
        @candidates.each { |obs| render_obs_box(obs) }
      end
    end

    def render_matrix_ul(&block)
      Row(
        element: :ul,
        class: "list-unstyled mt-3",
        data: {
          controller: "matrix-table",
          action: "resize@window->matrix-table#rearrange"
        },
        &block
      )
    end

    # Primary-obs inline edit section (edit mode only). Fields ride
    # under `occurrence[primary_observation][...]`; Superform
    # auto-resolves values through the `primary_observation` AR
    # association. The controller applies the params to the primary
    # observation manually.
    def render_details_section
      locations = distinct_locations
      h4(class: "mt-4") { plain(:edit_occurrence_details_heading.l) }
      namespace(:primary_observation) do |attrs_ns|
        render_location_select(attrs_ns, locations) if locations.size > 1
        render_date_field(attrs_ns)
      end
    end

    def render_location_select(attrs_ns, locations)
      # `locations` is already Rails-shape `[[name, id], ...]` from
      # `distinct_locations` — pass straight through to SelectField.
      render(attrs_ns.field(:location_id).select(
               locations,
               wrapper_options: { label: :edit_occurrence_location }
             ))
    end

    def render_date_field(attrs_ns)
      render(attrs_ns.field(:when).date(
               wrapper_options: { label: :WHEN, inline: true }
             ))
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

    # ---------- Shared per-row rendering ----------

    def render_obs_box(obs, &block)
      render(Components::Matrix::Box.new(user: @user, object: obs,
                                         votes: false)) do
        if block
          yield
        else
          render_obs_controls(obs)
        end
      end
    end

    def render_obs_controls(obs)
      render_include_checkbox(obs)
      render_primary_radio(obs)
      render_occurrence_warning(obs)
    end

    # `cb.option(value)` renders a single `<input type="checkbox"
    # name="occurrence[observation_ids][]" value="...">` wrapped in
    # MO's `.checkbox` div. The block becomes the label text.
    def render_include_checkbox(obs)
      checkbox_field(:observation_ids,
                     label: false, wrap_class: "my-0",
                     data: { action:
                               "occurrence-form#includeToggled" }) do |cb|
        cb.option(obs.id) { "Include" }
      end
    end

    # All radio rows render against the same
    # `primary_observation_id` field; only the option whose value
    # matches `field.value` (the source on initial new render, the
    # persisted primary on edit render) gets `checked`.
    def render_primary_radio(obs, source: false)
      radio_field(:primary_observation_id,
                  [obs.id, :create_occurrence_primary.l],
                  wrap_class: "my-0",
                  data: primary_radio_data(source: source))
    end

    def primary_radio_data(source:)
      data = { action: "occurrence-form#primarySelected" }
      data[:"occurrence-form-target"] = "sourceRadio" if source
      data
    end

    def render_occurrence_warning(obs)
      fs = obs.field_slip
      if fs
        render_field_slip_link(fs)
      elsif obs.occurrence&.observations&.many?
        render_occurrence_link(obs)
      end
    end

    def render_field_slip_link(field_slip)
      small(class: "d-block") do
        a(href: field_slip_path(field_slip)) do
          plain("Field Slip: #{field_slip.code}")
        end
      end
    end

    def render_occurrence_link(obs)
      Link(type: :icon, tab: Tab::Occurrence::Existing.new(obs: obs),
           show_text: true)
    end
  end
end
