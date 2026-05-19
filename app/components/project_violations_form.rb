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
      params: { project: { do: "exclude", obs_id: obs.id } }
    )
  end

  def render_extend_button(obs)
    button_to(
      :form_violations_action_extend.l, violations_path,
      method: :put, class: "btn btn-default btn-xs",
      params: { project: { do: "extend", obs_id: obs.id } }
    )
  end

  def render_add_target_name_button(obs)
    button_to(
      :form_violations_action_add_target_name.l, violations_path,
      method: :put, class: "btn btn-default btn-xs",
      params: { project: { do: "add_target_name", obs_id: obs.id } }
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

  # Per-obs modal. When the obs has usable suffixes, the body+footer
  # are owned by TargetLocationForm via Modal's `:form_content` slot
  # (so the form spans both — submit in the footer is naturally inside
  # the form). When there are no usable suffixes (e.g. obs.where is
  # just a country), there's nothing to submit, so render a static
  # message body + Cancel-only footer instead.
  def render_location_modal(obs)
    render(Components::Modal.new(
             id: location_modal_id(obs),
             title: :form_violations_modal_target_location_title.l,
             user: @user
           )) do |m|
      if Components::TargetLocationForm.applicable?(obs)
        m.with_form_content do
          render(Components::TargetLocationForm.new(
                   obs: obs, project: @project
                 ))
        end
      else
        render_no_suffixes_slots(m)
      end
    end
  end

  def render_no_suffixes_slots(modal)
    modal.with_body do
      p { :form_violations_modal_target_location_no_suffixes.l }
    end
    modal.with_footer do
      button(type: "button", class: "btn btn-default",
             data: { dismiss: "modal" }) { :CANCEL.l }
    end
  end

  def location_modal_id(obs)
    "location_target_modal_#{obs.id}"
  end
end
