# frozen_string_literal: true

# View Helpers for Projects, Project Violations
module ProjectsHelper
  def violation_table_headers(project)
    [
      nil, # column for checkbox
      "#{:CONSTRAINTS.l}:",
      "#{:DATES.l}: #{project.date_range}",
      violation_latitude_header(project),
      violation_longitude_header(project),
      violation_location_header(project),
      nil # column for observation.user
    ]
  end

  def violation_table_rows(form:, project:, violations:)
    violations.each_with_object([]) do |obs, rows|
      rows << [
        violation_checkbox(form: form, project: project, obs: obs),
        link_to_object(obs, obs.text_name) + " (#{obs.id})",
        styled_obs_when(project, obs),
        styled_obs_lat(project, obs),
        styled_obs_lng(project, obs),
        styled_obs_where(project, obs),
        user_link(obs.user)
      ]
    end
  end

  def violations_help_text(project)
    :form_violations_help.l if project.violations_removable_by_current_user?
  end

  def violations_submit_text(project)
    if project.violations_removable_by_current_user?
      :form_violations_remove_selected.l
    else
      :form_violations_show_project.l
    end
  end

  def field_slip_link(tracker)
    if tracker.status == "Done" && User.current == tracker.user
      link_to(tracker.filename, tracker.link)
    else
      tracker.filename
    end
  end

  def edit_project_alias_link(project_id, name, id)
    tag.span(id: "project_alias_#{id}") do
      modal_link_to(
        "project_alias_#{id}",
        *edit_project_alias_tab(project_id, name, id)
      )
    end
  end

  def new_project_alias_link(project_id, target_id, target_type)
    tag.span(id: "project_alias") do
      modal_link_to(
        "project_alias",
        *new_project_alias_tab(project_id, target_id, target_type)
      )
    end
  end

  def project_alias_headers
    [:NAME.t, :TARGET_TYPE.t, :TARGET.t, :ACTIONS.t]
  end

  def project_alias_rows(project_aliases)
    project_aliases.map do |project_alias|
      project_alias_row(project_alias)
    end
  end

  def project_alias_row(project_alias)
    [
      project_alias.name,
      project_alias.target_type,
      link_to(project_alias.target.try(:format_name), project_alias.target),
      project_alias_actions(project_alias.id, project_alias.project_id)
    ]
  end

  def project_alias_actions(id, project_id)
    capture do
      concat(link_to(:EDIT.t,
                     edit_project_alias_path(project_id:, id:)))
      concat(" ")
      concat(link_to(:DELETE.t,
                     project_alias_path(project_id:, id:),
                     data: { turbo_method: :delete,
                             turbo_confirm: :are_you_sure.t }))
    end
  end

  #########

  private

  def edit_project_alias_tab(project_id, name, id)
    InternalLink::Model.new(
      name, ProjectAlias,
      add_query_param(edit_project_alias_path(project_id:, id:)),
      alt_title: :EDIT.t
    ).tab
  end

  def new_project_alias_tab(project_id, target_id, target_type)
    InternalLink::Model.new(
      :ADD.t, ProjectAlias,
      add_query_param(new_project_alias_path(project_id:,
                                             target_id:,
                                             target_type:)),
      html_options: { class: "btn btn-default" }
    ).tab
  end

  def violation_latitude_header(project)
    return :form_violations_latitude_none.l unless project.location

    "Lat: #{project.location.north} to #{project.location.south}"
  end

  def violation_longitude_header(project)
    return :form_violations_longitude_none.l unless project.location

    "Lon: #{project.location.west} to #{project.location.east}"
  end

  def violation_location_header(project)
    return :form_violations_location_none.t unless project.location

    location_link(project.location.display_name, project.location,
                  nil, false)
  end

  def violation_checkbox(form:, project:, obs:)
    if violation_checkbox_viewers(project, obs).include?(User.current.id)
      form.check_box("remove_#{obs.id}")
    end
  end

  def violation_checkbox_viewers(project, obs)
    project.admin_group_user_ids + [obs.user_id]
  end

  def styled_obs_when(project, obs)
    if project.violates_date_range?(obs)
      tag.span(obs.when, class: "violation-highlight")
    else
      obs.when
    end
  end

  def styled_obs_lat(project, obs)
    return "" if obs.lat.blank?

    displayed_coord =
      coord_or_hidden(obs: obs, project: project, coord: obs.lat)

    return displayed_coord if project.location_id.nil?
    return displayed_coord if project.location.contains_lat?(obs.lat)

    tag.span(displayed_coord, class: "violation-highlight")
  end

  def styled_obs_lng(project, obs)
    return "" if obs.lng.blank?

    displayed_coord =
      coord_or_hidden(obs: obs, project: project, coord: obs.lng)

    return displayed_coord if project.location_id.nil?
    return displayed_coord if project.location.contains_lng?(obs.lng)

    tag.span(displayed_coord, class: "violation-highlight")
  end

  def coord_or_hidden(obs:, project:, coord:)
    if !obs.gps_hidden? ||
       User.current == obs.user ||
       project.trusted_by?(User.current) && project.admin?(User.current)
      coord
    else
      :hidden.l
    end
  end

  def styled_obs_where(project, obs)
    if obs.lat.present? || # If lat/lon present, ignore Location for compliance
       project&.location&.found_here?(obs)
      location_link(obs.place_name, obs.location, nil, false)
    else
      tag.span(location_link(obs.place_name, obs.location, nil, false),
               class: "violation-highlight")
    end
  end
end
