# frozen_string_literal: true

module Views::Controllers::FieldSlips
  # Phlex form for creating and editing FieldSlip records.
  #
  # When the field slip has no code yet, renders a minimal "enter
  # code" form that GETs to /field_slips/new. Otherwise renders the
  # full editing form with all field-slip attributes, notes, and
  # (depending on action / context) one of the two observation-matrix
  # sections.
  class Form < ::Components::ApplicationForm
    def initialize(model, **options)
      @species_list = options.delete(:species_list)
      @recent_observations = options.delete(:recent_observations) || []
      @user = options.delete(:user)
      # Explicit splat: bare `super` would forward the *original*
      # kwargs including the FieldSlipForm-only keys deleted above,
      # which would confuse the upstream initializer.
      super(model, **options) # rubocop:disable Style/SuperArguments
    end

    def view_template
      super do
        if model.code
          render_main_form
        else
          render_code_only_form
        end
      end
    end

    def form_action
      return new_field_slip_path unless model.code

      model.new_record? ? field_slips_path : field_slip_path(model)
    end

    private

    # Override form_tag so we can use GET for the code-only entry form.
    def form_tag(&block)
      if model.code
        super
      else
        form(action: form_action, method: :get,
             **form_attributes, &block)
      end
    end

    def form_attributes
      { id: @attributes[:id] || "field_slip_form" }
    end

    # --- "Code only" form: no field-slip code yet, just collect one.

    def render_code_only_form
      text_field(:code, label: "#{:field_slip_code.t}:")
      submit(:field_slip_create_obs.t, class: "mt-5")
    end

    # --- Main form: full field-slip editing.

    def render_main_form
      render_errors if model.errors.any?
      # Width-cap the texty fields to a comfortable reading width
      # (`.container-text`), but keep the observation matrix full-
      # width. Both must live inside the same `<form>` so the matrix
      # submits with the rest — hence the in-form wrap rather than a
      # page-level `container_class(:text)`.
      #
      # `species_list` hidden field always emitted (matching ERB
      # `hidden_field_tag`): the param key has to exist on submit;
      # an empty value is fine and the form context
      # (`?species_list=...`) is what carries the actual id.
      hidden_field("species_list", value: @species_list)
      div(class: "container-text") do
        render_left_column_fields
        render_submit_quick_create if new_record?
        render_notes_panel
        render_submit_add_images if new_record?
      end
      render_observations_section
      render_edit_action_submits unless new_record?
    end

    # MO convention (cf. `descriptions/form.rb`): forms distinguish
    # "new" vs "edit" rendering via the model's persistence state.
    # Naturally handles the create/update re-render paths too —
    # validation failure leaves persistence state unchanged.
    def new_record?
      model.new_record?
    end

    # --- Errors ---

    def render_errors
      count = pluralize(model.errors.count, :error.t, plural: :errors.t)
      render(Components::Alert.new(level: :danger)) do
        ul do
          model.errors.each { |error| li { error.full_message } }
        end
      end
      p { "#{count} #{:field_slip_errors.t}:" }
    end

    # --- Left-column field-slip attribute fields ---

    def render_left_column_fields
      text_field(:code, label: "#{:field_slip_code.t}:")
      render_project_select if model.projects.present?
      render_date_field
      render_collector_field
      render_location_field
      render_field_slip_name_field
      render_field_slip_id_by_field
      text_field(:other_codes,
                 label: "#{:field_slip_other_codes.t} " \
                        "(#{:field_slip_other_example.t}):")
      checkbox_field(:inat, label: :field_slip_other_inat.t)
    end

    def render_project_select
      # `FieldSlip#projects` returns Rails-shape `[[title, id], ...]`
      # — pass through to SelectField.
      select_field(:project_id, model.projects,
                   inline: true,
                   label: "#{:Project.t}:",
                   selected: model.project&.id)
    end

    def render_date_field
      today = Time.zone.today
      date_field(:date,
                 label: "#{:DATE.t}:",
                 inline: true,
                 start_year: today.year - 10,
                 end_year: today.year + 10)
    end

    def render_collector_field
      autocompleter_field(:collector,
                          type: :user,
                          label: "#{:COLLECTOR.t}:")
    end

    def render_location_field
      autocompleter_field(:location,
                          type: :location,
                          label: "#{:LOCATION.t}:",
                          value: model.location_name,
                          hidden_value: model.location_id)
    end

    def render_field_slip_name_field
      autocompleter_field(:field_slip_name,
                          type: :name,
                          label: "#{:ID.t}:")
    end

    def render_field_slip_id_by_field
      autocompleter_field(:field_slip_id_by,
                          type: :user,
                          label: "#{:ID_BY.t}:")
    end

    # --- Notes ---

    def render_notes_panel
      render(Components::Form::Notes.new(
               form: self,
               parts: field_slip_note_parts,
               panel_id: "field_slip_notes",
               expanded: true
             ))
    end

    # Normalize FieldSlip's `NoteField` objects (`.name`/`.value`/`.label`)
    # into the uniform `FormNotes::Part` shape the shared component
    # consumes.
    def field_slip_note_parts
      model.notes_fields.map do |part|
        Components::Form::Notes::Part.new(
          key: part.name,
          value: part.value,
          label: "#{part.label}:"
        )
      end
    end

    # --- Submit buttons (matching ERB layout) ---

    def render_submit_quick_create
      submit(:field_slip_quick_create_obs.t, class: "mb-5")
    end

    def render_submit_add_images
      submit(:field_slip_add_images.t, class: "mt-5")
    end

    def render_edit_action_submits
      submit(:SAVE_EDITS.t, class: "my-3")
      submit(:field_slip_create_obs.t, class: "my-3")
    end

    # --- Observation matrix section ---

    def render_observations_section
      if new_record? && @recent_observations.any?
        div(class: "clearfix")
        render_new_action_matrix
      elsif !new_record?
        div(class: "clearfix")
        render_edit_action_matrices
      end
    end

    # New action: one matrix of recent obs, all unchecked, plus
    # "Save with Selected Observations" submit.
    def render_new_action_matrix
      div(class: "mt-5") do
        strong { "#{:field_slip_select_observations.t}:" }
        render_observation_matrix(@recent_observations,
                                  checked_ids: [],
                                  primary_id: nil)
        submit(:field_slip_save_with_observations.t,
               class: "mt-3 mb-5")
      end
    end

    # Edit action: a matrix of current obs (checked) and a matrix of
    # candidate obs (unchecked).
    def render_edit_action_matrices
      div(class: "mt-5", data: { controller: "field-slip-form" }) do
        current = current_observations
        primary_id = current_primary_id(current)
        if current.any?
          strong { "#{:OBSERVATIONS.t}:" }
          render_observation_matrix(current,
                                    checked_ids: current.map(&:id),
                                    primary_id: primary_id)
        end
        if @recent_observations.any?
          strong { "#{:field_slip_select_observations.t}:" }
          render_observation_matrix(@recent_observations,
                                    checked_ids: [],
                                    primary_id: primary_id)
        end
      end
    end

    def current_observations
      @current_observations ||= model.observations.
                                includes(:name, :user, :location, :thumb_image).
                                order(:created_at).to_a
    end

    def current_primary_id(current)
      occ = model.occurrence
      return occ.primary_observation_id if occ

      current.one? ? current.first&.id : nil
    end

    def render_observation_matrix(observations, checked_ids:, primary_id:)
      # FieldSlip submits matrix params as flat `observation_ids[]`
      # and namespaced `field_slip[primary_observation_id]` — both
      # unchanged from the ERB version, so the controller doesn't
      # need to move. FieldSlip doesn't have an `observation_ids=`
      # accessor (the join is via the occurrence), so we drive both
      # fields through the String form of `checkbox_field` /
      # `radio_field` — raw `name=` attribute, value carried by the
      # `value:` option, no Superform model binding.
      @checked_ids = checked_ids
      @primary_id = primary_id
      ul(class: "row list-unstyled mt-3", data: matrix_data) do
        observations.each { |obs| render_observation_row(obs) }
      end
    end

    def matrix_data
      {
        controller: "matrix-table field-slip-form",
        action: "resize@window->matrix-table#rearrange"
      }
    end

    def render_observation_row(obs)
      render(Components::Matrix::Box.new(user: @user, object: obs,
                                         votes: false)) do
        render_include_checkbox(obs)
        render_primary_radio(obs)
        render_field_slip_link(obs.field_slip) if obs.field_slip
      end
    end

    # `cb.option(obs.id)` renders one `<input type="checkbox"
    # name="observation_ids[]" value="…">`. CheckboxField looks up
    # `checked` via membership of `obs.id` in the field's value (the
    # array of currently-checked ids passed as `value:` here).
    def render_include_checkbox(obs)
      checkbox_field("observation_ids",
                     value: @checked_ids,
                     label: false, wrap_class: "my-0",
                     data: { action: "field-slip-form#includeToggled" }) do |cb|
        cb.option(obs.id) { "Include" }
      end
    end

    def render_primary_radio(obs)
      radio_field("field_slip[primary_observation_id]",
                  [obs.id, :create_occurrence_primary.t],
                  value: @primary_id,
                  wrap_class: "my-0",
                  data: { action: "field-slip-form#primarySelected" })
    end

    def render_field_slip_link(field_slip)
      small do
        a(href: field_slip_path(field_slip)) do
          "Field Slip: #{field_slip.code}"
        end
      end
    end
  end
end
