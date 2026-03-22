# frozen_string_literal: true

# Form for creating an Occurrence by selecting observations.
# Renders a grid of observation matrix boxes with Include
# checkboxes and Primary radio buttons.
class Components::OccurrenceForm < Components::ApplicationForm
  def initialize(source_obs:, recent_observations:, user:, **)
    @source_obs = source_obs
    @recent_observations = recent_observations
    @user = user
    form_object = FormObject::Occurrence.new(
      observation_id: source_obs.id,
      primary_observation_id: source_obs.id
    )
    super(form_object, **)
  end

  def view_template
    hidden_field(:observation_id)
    render_observation_grid
    input(type: "submit", value: :create_occurrence_submit.l,
          class: "btn btn-default center-block my-3")
  end

  def form_action
    occurrences_path
  end

  private

  def render_observation_grid
    all_obs = [@source_obs] + @recent_observations
    ul(
      class: "row list-unstyled mt-3",
      data: {
        controller: "matrix-table occurrence-form",
        action: "resize@window->matrix-table#rearrange"
      }
    ) do
      all_obs.each { |obs| render_obs_box(obs) }
    end
  end

  def render_obs_box(obs)
    MatrixBox(user: @user, object: obs, votes: false) do
      render_obs_controls(obs)
    end
  end

  def render_obs_controls(obs)
    if obs == @source_obs
      render_source_controls(obs)
    else
      render_recent_controls(obs)
    end
  end

  def render_source_controls(obs)
    input(type: "hidden", name: "observation_ids[]",
          value: obs.id)
    strong { plain(:create_occurrence_source.l) }
    br
    render_primary_radio(obs, checked: true)
  end

  def render_recent_controls(obs)
    render_include_checkbox(obs)
    br
    render_primary_radio(obs, checked: false)
    render_occurrence_warning(obs)
  end

  def render_include_checkbox(obs)
    label do
      input(type: "checkbox", name: "observation_ids[]",
            value: obs.id,
            data: {
              action: "occurrence-form#includeToggled"
            })
      whitespace
      plain("Include")
    end
  end

  def render_primary_radio(obs, checked:)
    label do
      input(type: "radio",
            name: "occurrence[primary_observation_id]",
            value: obs.id,
            checked: checked || nil,
            data: primary_radio_data(obs, checked))
      whitespace
      plain(:create_occurrence_primary.l)
    end
  end

  def primary_radio_data(obs, checked)
    data = { action: "occurrence-form#primarySelected" }
    if obs == @source_obs && checked
      data[:"occurrence-form-target"] = "sourceRadio"
    end
    data
  end

  def render_occurrence_warning(obs)
    fs = obs.field_slip
    if fs
      render_field_slip_link(fs)
    elsif obs.occurrence&.observations&.many?
      render_multi_occurrence_link(obs)
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

  def render_multi_occurrence_link(obs)
    br
    a(href: occurrence_path(obs.occurrence_id)) do
      span(class: "glyphicon glyphicon-th-large")
      plain(" ")
      plain(:in_existing_occurrence.l)
    end
  end
end
