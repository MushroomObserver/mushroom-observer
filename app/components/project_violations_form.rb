# frozen_string_literal: true

# Form for viewing and removing project constraint violations.
# Renders a table of non-compliant observations with checkboxes
# for removal by authorized users.
class Components::ProjectViolationsForm < Components::ApplicationForm
  def initialize(model, violations:, user:, **)
    @violations = violations
    @user = user
    super(model, id: "project_violations_form", **)
  end

  def view_template
    h4 do
      trusted_html("#{:PROJECT.l}: ")
      link_to_object(model)
    end
    super do
      render_help_text
      render_violations_table
      submit(submit_text)
    end
  end

  def form_action
    project_violations_update_path(project_id: model.id)
  end

  private

  def render_help_text
    return unless model.violations_removable_by_current_user?

    help_block(:div, :form_violations_help.l)
  end

  def submit_text
    if model.violations_removable_by_current_user?
      :form_violations_remove_selected.l
    else
      :form_violations_show_project.l
    end
  end

  def render_violations_table
    render(Components::Table.new(@violations)) do |t|
      define_columns(t)
    end
  end

  def define_columns(tbl)
    tbl.column(nil) { |obs| render_checkbox(obs) }
    tbl.column("#{:CONSTRAINTS.l}:") do |obs|
      render_obs_link(obs)
    end
    tbl.column("#{:DATES.l}: #{model.date_range}") do |obs|
      styled_obs_when(obs)
    end
    define_location_columns(tbl)
    tbl.column(nil) { |obs| user_link(obs.user) }
  end

  def define_location_columns(tbl)
    tbl.column(latitude_header) do |obs|
      styled_obs_lat(obs)
    end
    tbl.column(longitude_header) do |obs|
      styled_obs_lng(obs)
    end
    tbl.column(location_header) do |obs|
      styled_obs_where(obs)
    end
  end

  def render_checkbox(obs)
    return unless can_remove?(obs)

    checkbox_field("remove_#{obs.id}", label: false)
  end

  def can_remove?(obs)
    (model.admin_group_user_ids + [obs.user_id]).
      include?(@user.id)
  end

  def render_obs_link(obs)
    link_to_object(obs, obs.text_name)
    plain(" (#{obs.id})")
  end

  # Column headers

  def latitude_header
    return :form_violations_latitude_none.l unless model.location

    "Lat: #{model.location.north} to #{model.location.south}"
  end

  def longitude_header
    return :form_violations_longitude_none.l unless model.location

    "Lon: #{model.location.west} to #{model.location.east}"
  end

  def location_header
    return :form_violations_location_none.t unless model.location

    # Capture output helper result as string (location_link
    # is an output helper that writes directly to buffer).
    capture do
      location_link(
        model.location.display_name, model.location,
        nil, false
      )
    end
  end

  # Styled cell methods

  def styled_obs_when(obs)
    if model.violates_date_range?(obs)
      span(class: "violation-highlight") { obs.when.to_s }
    else
      plain(obs.when.to_s)
    end
  end

  def styled_obs_lat(obs)
    return if obs.lat.blank?

    displayed = coord_or_hidden(obs, obs.lat)
    if model.location_id.nil? ||
       model.location.contains_lat?(obs.lat)
      trusted_html(displayed.to_s)
    else
      span(class: "violation-highlight") do
        trusted_html(displayed.to_s)
      end
    end
  end

  def styled_obs_lng(obs)
    return if obs.lng.blank?

    displayed = coord_or_hidden(obs, obs.lng)
    if model.location_id.nil? ||
       model.location.contains_lng?(obs.lng)
      trusted_html(displayed.to_s)
    else
      span(class: "violation-highlight") do
        trusted_html(displayed.to_s)
      end
    end
  end

  def coord_or_hidden(obs, coord)
    if !obs.gps_hidden? ||
       @user == obs.user ||
       model.trusted_by?(@user) && model.admin?(@user)
      coord
    else
      :hidden.l
    end
  end

  def styled_obs_where(obs)
    # Capture output helper result as string (location_link
    # is an output helper that writes directly to buffer).
    loc_html = capture do
      location_link(obs.place_name, obs.location, nil, false)
    end
    if obs.lat.present? || model&.location&.found_here?(obs)
      trusted_html(loc_html)
    else
      span(class: "violation-highlight") do
        trusted_html(loc_html)
      end
    end
  end
end
