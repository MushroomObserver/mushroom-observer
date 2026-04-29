# frozen_string_literal: true

# One row per violating observation (#4136). Each row shows the obs's
# name, the kinds of violation that apply, the relevant detail
# (date / lat,lng / location), and per-kind action buttons keyed
# off `Project::VIOLATION_KINDS`:
#
#   :date              - obs.when outside project.start_date / end_date
#                        Action: Exclude, Extend
#   :bbox              - obs's GPS / location not contained in
#                        project.location's bbox
#                        Action: Exclude (no auto-widen of project bbox)
#   :target_name       - project has target_names but obs.name is not in
#                        the expansion (synonyms + sub-taxa)
#                        Action: Exclude, Add Target Name
#   :target_location   - project has target_locations but no comma-suffix
#                        of obs.location.name (or obs.where) matches
#                        Action: Exclude, Add Target Location (modal)
#
# Exclude is offered to admins and the obs's own user. The other
# actions are admin-only because they mutate project-level config.
class Components::ProjectViolationsForm < Components::Base
  register_value_helper :form_authenticity_token

  prop :project, Project
  prop :violations, _Array(Project::Violation)
  prop :user, User

  def view_template
    h4 do
      trusted_html("#{:PROJECT.l}: ")
      link_to_object(@project)
    end

    if @violations.empty?
      p { :form_violations_no_violations.l }
      return
    end

    help_block(:div, :form_violations_help.l)
    render_violations_table
    render_location_modals
  end

  private

  def admin?
    @admin ||= @project.is_admin?(@user)
  end

  def can_exclude?(obs)
    admin? || obs.user_id == @user.id
  end

  def violations_path
    project_violations_update_path(project_id: @project.id)
  end

  def render_violations_table
    table(class: "table table-striped project-violations") do
      thead do
        tr do
          th { :form_violations_th_name.l }
          th { :form_violations_th_details.l }
          th { :form_violations_th_actions.l }
        end
      end
      tbody do
        @violations.each { |v| render_row(v) }
      end
    end
  end

  def render_row(violation)
    obs = violation.obs
    kinds = violation.kinds
    tr do
      td { render_obs_link(obs) }
      td { render_details(obs, kinds) }
      td { render_actions(obs, kinds) }
    end
  end

  def render_obs_link(obs)
    link_to_object(obs, obs.text_name)
    plain(" (#{obs.id})")
  end

  def kind_label(kind)
    :"form_violations_kind_#{kind}".l
  end

  def render_details(obs, kinds)
    parts = kinds.filter_map { |k| detail_for(obs, k) }
    parts.each_with_index do |line, i|
      br if i.positive?
      plain(line)
    end
  end

  def detail_for(obs, kind)
    case kind
    when :date
      "#{kind_label(:date)}: #{obs.when} (#{@project.date_range})"
    when :bbox
      bbox_detail(obs)
    when :target_name
      "#{kind_label(:target_name)}: #{obs.text_name}"
    when :target_location
      "#{kind_label(:target_location)}: #{obs_where(obs)}"
    end
  end

  def bbox_detail(obs)
    if obs.lat.present?
      "#{kind_label(:bbox)}: #{obs.lat}, #{obs.lng}"
    else
      "#{kind_label(:bbox)}: #{obs_where(obs)}"
    end
  end

  def obs_where(obs)
    obs.location_id ? obs.location&.name : obs.where
  end

  def render_actions(obs, kinds)
    render_exclude_button(obs) if can_exclude?(obs)
    return unless admin?

    render_extend_button(obs) if kinds.include?(:date)
    render_add_target_name_button(obs) if kinds.include?(:target_name)
    render_add_target_location_trigger(obs) if kinds.include?(:target_location)
  end

  def render_exclude_button(obs)
    button_to(
      :form_violations_action_exclude.l, violations_path,
      method: :put, class: "btn btn-default btn-xs",
      params: { do: "exclude", obs_id: obs.id }
    )
  end

  def render_extend_button(obs)
    button_to(
      :form_violations_action_extend.l, violations_path,
      method: :put, class: "btn btn-default btn-xs",
      params: { do: "extend", obs_id: obs.id }
    )
  end

  def render_add_target_name_button(obs)
    button_to(
      :form_violations_action_add_target_name.l, violations_path,
      method: :put, class: "btn btn-default btn-xs",
      params: { do: "add_target_name", obs_id: obs.id }
    )
  end

  def render_add_target_location_trigger(obs)
    button(
      type: "button",
      class: "btn btn-default btn-xs",
      data: {
        toggle: "modal",
        target: "##{location_modal_id(obs)}"
      }
    ) { :form_violations_action_add_target_location.l }
  end

  def render_location_modals
    @violations.each do |v|
      next unless admin? && v.kinds.include?(:target_location)

      render_location_modal(v.obs)
    end
  end

  def render_location_modal(obs)
    div(
      class: "modal fade",
      id: location_modal_id(obs),
      tabindex: "-1",
      role: "dialog",
      aria: { labelledby: "#{location_modal_id(obs)}_label" }
    ) do
      div(class: "modal-dialog", role: "document") do
        div(class: "modal-content") do
          render_location_modal_header(obs)
          render_location_modal_body(obs)
        end
      end
    end
  end

  def render_location_modal_header(obs)
    div(class: "modal-header") do
      button(
        type: "button", class: "close",
        data: { dismiss: "modal" }, aria: { label: :CLOSE.l }
      ) do
        span(aria: { hidden: "true" }) { "×" }
      end
      h4(class: "modal-title", id: "#{location_modal_id(obs)}_label") do
        plain(:form_violations_modal_target_location_title.l)
      end
    end
  end

  def render_location_modal_body(obs)
    suffixes = location_suffixes_for(obs)
    if suffixes.empty?
      div(class: "modal-body") do
        p { :form_violations_modal_target_location_no_suffixes.l }
      end
      div(class: "modal-footer") do
        button(
          type: "button", class: "btn btn-default",
          data: { dismiss: "modal" }
        ) { :CANCEL.l }
      end
    else
      render_suffix_form(obs, suffixes)
    end
  end

  def render_suffix_form(obs, suffixes)
    form(method: "post", action: violations_path) do
      render_csrf_and_method
      input(type: "hidden", name: "do", value: "add_target_location")
      input(type: "hidden", name: "obs_id", value: obs.id)
      div(class: "modal-body") { render_suffix_radios(obs, suffixes) }
      render_modal_footer
    end
  end

  def render_modal_footer
    div(class: "modal-footer") do
      button(
        type: "submit", class: "btn btn-primary"
      ) { :form_violations_modal_target_location_submit.l }
      button(
        type: "button", class: "btn btn-default",
        data: { dismiss: "modal" }
      ) { :CANCEL.l }
    end
  end

  def render_suffix_radios(obs, suffixes)
    p { :form_violations_modal_target_location_help.l }
    suffixes.each_with_index do |suffix, i|
      div(class: "radio") { render_suffix_choice(obs, suffix, i) }
    end
  end

  def render_suffix_choice(_obs, suffix, index)
    existing = Location.find_by(name: suffix)
    label do
      if existing
        input(type: "radio", name: "location_id",
              value: existing.id, checked: index.zero?)
        plain(" #{suffix}")
      else
        input(type: "radio", name: "location_id", disabled: true)
        plain(" #{suffix} ")
        a(
          href: new_location_path(display_name: suffix),
          target: "_blank", rel: "noopener",
          class: "btn btn-default btn-xs"
        ) { :form_violations_modal_target_location_create.l }
      end
    end
  end

  def render_csrf_and_method
    input(type: "hidden", name: "_method", value: "put")
    input(type: "hidden", name: "authenticity_token",
          value: form_authenticity_token)
  end

  def location_modal_id(obs)
    "location_target_modal_#{obs.id}"
  end

  # Return the comma-suffixes of the obs's location (or where), excluding
  # any suffix that is a bare country name (Q3 of #4136 design).
  def location_suffixes_for(obs)
    name = obs.location_id ? obs.location&.name : obs.where
    return [] if name.blank?

    suffixes = comma_suffixes(name)
    suffixes.reject { |s| Location.understood_countries.include?(s) }
  end

  def comma_suffixes(name)
    parts = name.split(",").map(&:strip).reject(&:empty?)
    return [] if parts.length < 2

    (1..(parts.length - 1)).map { |i| parts[i..].join(", ") }
  end
end
