# frozen_string_literal: true

# Form for editing an Occurrence: change primary observation and
# remove observations. Renders a grid of observation boxes with
# Primary radio buttons and Remove checkboxes.
class Components::OccurrenceEditForm < Components::ApplicationForm
  register_output_helper :location_link, mark_safe: true
  register_output_helper :show_title_id_badge, mark_safe: true
  register_output_helper :user_link, mark_safe: true

  def initialize(occurrence:, observations:, candidates:,
                 user:, **)
    @occurrence = occurrence
    @observations = observations
    @candidates = candidates
    @user = user
    form_object = FormObject::Occurrence.new(
      observation_id: occurrence.primary_observation_id,
      primary_observation_id: occurrence.primary_observation_id
    )
    super(form_object, **)
  end

  def view_template
    super do
      render_details_section
      render_submit
      render_observation_grid
      render_candidate_section if @candidates.any?
      render_create_observation_button
    end
  end

  def form_action
    occurrence_path(@occurrence)
  end

  private

  def form_tag(&block)
    form(action: form_action, method: :post,
         **form_attributes, &block)
  end

  def form_attributes
    {
      id: "occurrence_edit_form",
      data: { controller: "occurrence-edit-form" }
    }
  end

  def hidden_method_field
    input(type: "hidden", name: "_method", value: "patch")
  end

  def render_observation_grid
    hidden_method_field
    # Ensure observation_ids param exists even when all unchecked
    input(type: "hidden", name: "observation_ids[]", value: "")
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

  def render_submit
    input(type: "submit", value: :edit_occurrence_submit.l,
          class: "btn btn-default center-block my-3")
  end

  def render_obs_box(obs, &footer)
    li(class: "matrix-box col-xs-12 col-sm-6 col-md-4 col-lg-3") do
      render(Components::Panel.new(sizing: true)) do |panel|
        render_obs_thumbnail(panel, obs)
        render_obs_details(panel, obs)
        panel.with_footer(classes: "text-center") do
          footer ? yield : render_obs_controls(obs)
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
        whitespace
        show_title_id_badge(obs, "rss-id")
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
    is_primary = obs.id == @occurrence.primary_observation_id
    render_include_checkbox(obs, checked: true)
    br
    render_primary_radio(obs, checked: is_primary)
    render_occurrence_warning(obs)
  end

  def render_primary_radio(obs, checked:)
    label do
      input(
        type: "radio",
        name: "occurrence[primary_observation_id]",
        value: obs.id,
        checked: checked || nil,
        data: {
          action: "occurrence-edit-form#primarySelected",
          editable: obs.can_edit?(@user) ? "true" : "false"
        }
      )
      whitespace
      plain(:create_occurrence_primary.l)
    end
  end

  def render_include_checkbox(obs, checked:)
    label do
      input(
        type: "checkbox",
        name: "observation_ids[]",
        value: obs.id,
        checked: checked || nil,
        data: {
          action: "occurrence-edit-form#includeToggled"
        }
      )
      whitespace
      plain("Include")
    end
  end

  def render_details_section
    locations = distinct_locations
    h4(class: "mt-4") { plain(:edit_occurrence_details_heading.l) }
    render_location_select(locations) if locations.size > 1
    render_date_input
  end

  def render_location_select(locations)
    current_loc = primary_obs.location_id
    label(for: "primary_obs_location_id") { plain(:edit_occurrence_location.l) }
    select(name: "primary_obs[location_id]",
           id: "primary_obs_location_id",
           class: "form-control") do
      locations.each do |name, id|
        option(value: id,
               selected: (id == current_loc) || nil) { plain(name) }
      end
    end
  end

  def render_date_input
    label(for: "primary_obs_when", class: "mt-2") { plain("#{:WHEN.l}:") }
    input(
      type: "date",
      name: "primary_obs[when]",
      id: "primary_obs_when",
      value: primary_obs.when.to_s,
      class: "form-control"
    )
  end

  def render_create_observation_button
    input(
      type: "submit", name: "create_observation",
      value: :edit_occurrence_create_obs.l,
      class: "btn btn-default center-block my-3",
      disabled: primary_obs.can_edit?(@user) || nil,
      data: { occurrence_edit_form_target: "createObsButton" }
    )
    p(class: "help-block") { plain(:edit_occurrence_create_obs_help.l) }
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

  def primary_obs
    default_id = @occurrence.primary_observation_id
    @observations.find { |o| o.id == default_id } ||
      @observations.first
  end

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
        render_obs_box(obs) do
          render_include_checkbox(obs, checked: false)
          br
          render_primary_radio(obs, checked: false)
          render_occurrence_warning(obs)
        end
      end
    end
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
