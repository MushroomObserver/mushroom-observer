# frozen_string_literal: true

# Form for creating an Occurrence by selecting observations.
# Renders a grid of observation matrix boxes with Include
# checkboxes and Primary radio buttons.
class Components::OccurrenceForm < Components::ApplicationForm
  register_output_helper :location_link, mark_safe: true
  register_output_helper :user_link, mark_safe: true

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
    li(class: "matrix-box col-xs-12 col-sm-6 col-md-4 col-lg-3") do
      render(Components::Panel.new(sizing: true)) do |panel|
        render_obs_thumbnail(panel, obs)
        render_obs_details(panel, obs)
        panel.with_footer(classes: "text-center") do
          render_obs_controls(obs)
        end
      end
    end
  end

  def render_obs_thumbnail(panel, obs)
    return unless obs.thumb_image

    panel.with_thumbnail do
      InteractiveImage(
        user: @user,
        image: obs.thumb_image,
        image_link: { controller: :observations,
                      action: :show, id: obs.id },
        obs: { id: obs.id, name: obs.name },
        votes: false,
        full_width: true
      )
    end
  end

  def render_obs_details(panel, obs)
    panel.with_body(classes: "rss-box-details") do
      render_obs_name(obs)
      render_obs_location(obs)
      render_obs_when_who(obs)
    end
  end

  def render_obs_name(obs)
    div(class: "rss-what") do
      h5(class: "mt-0 rss-heading h5") do
        a(href: observation_path(obs)) do
          trusted_html(
            obs.format_name.t.break_name.small_author
          )
        end
      end
    end
  end

  def render_obs_location(obs)
    div(class: "rss-where") do
      small { location_link(obs.place_name, obs.location) }
    end
  end

  def render_obs_when_who(obs)
    div(class: "rss-what") do
      small(class: "nowrap-ellipsis") do
        span(class: "rss-when") { plain(obs.when.to_s) }
        plain(": ")
        user_link(obs.user, nil, class: "rss-who")
      end
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
    return unless obs.occurrence

    br
    span(class: "text-warning") do
      plain("(in Occurrence ##{obs.occurrence_id})")
    end
  end
end
