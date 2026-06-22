# frozen_string_literal: true

# One row per violating observation (#4136). Each row shows the
# obs's name, the kinds of violation that apply, the relevant
# detail (date / lat,lng / location), and per-kind action buttons
# keyed off `Project::VIOLATION_KINDS`:
#
#   :date              - obs.when outside project.start_date / end_date
#                        Action: Exclude, Extend
#   :bbox              - obs's GPS / location not contained in
#                        project.location's bbox
#                        Action: Exclude (no auto-widen of project bbox)
#   :target_name       - project has target_names but obs.name is not
#                        in the expansion (synonyms + sub-taxa)
#                        Action: Exclude, Add Target Name
#   :target_location   - project has target_locations but no comma-suffix
#                        of obs.location.name (or obs.where) matches
#                        Action: Exclude, Add Target Location (modal)
#
# Exclude is offered to admins and the obs's own user. The other
# actions are admin-only because they mutate project-level config.
module Views::Controllers::Projects::Violations
  class Form < Views::Base
    prop :project, Project
    prop :violations, _Array(Project::Violation)
    prop :user, User

    def view_template
      h4 do
        trusted_html("#{:PROJECT.l}: ")
        render(Components::Link::Object::Base.new(object: @project))
      end

      if @violations.empty?
        p { :form_violations_no_violations.l }
        return
      end

      render(Components::Help::Block.new(:div, :form_violations_help.l))
      render_violations_table
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
      render(Components::Table.new(@violations,
                                   class: "table-striped " \
                                          "project-violations")) do |t|
        t.column(:form_violations_th_name.l) { |v| render_obs_link(v.obs) }
        t.column(:form_violations_th_details.l) do |v|
          render_details(v.obs, v.kinds)
        end
        t.column(:form_violations_th_actions.l) do |v|
          render_actions(v.obs, v.kinds)
        end
      end
    end

    def render_obs_link(obs)
      render(Components::Link::Object::Base.new(object: obs,
                                                name: obs.text_name))
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
      return unless kinds.include?(:target_location)

      render_add_target_location_trigger(obs)
    end

    def render_exclude_button(obs)
      render(::Components::Button.new(
               type: :put,
               name: :form_violations_action_exclude.l,
               target: violations_path,
               params: { project: { do: "exclude", obs_id: obs.id } },
               size: :xs
             ))
    end

    def render_extend_button(obs)
      render(::Components::Button.new(
               type: :put,
               name: :form_violations_action_extend.l,
               target: violations_path,
               params: { project: { do: "extend", obs_id: obs.id } },
               size: :xs
             ))
    end

    def render_add_target_name_button(obs)
      render(::Components::Button.new(
               type: :put,
               name: :form_violations_action_add_target_name.l,
               target: violations_path,
               params: { project: { do: "add_target_name", obs_id: obs.id } },
               size: :xs
             ))
    end

    # The modal markup itself is no longer rendered eagerly — each
    # click hits `Projects::ViolationsController#target_location_modal`
    # which renders a fresh
    # `Views::Controllers::Projects::Violations::TargetLocationModal`
    # via turbo-stream. The `modal-toggle` Stimulus controller fetches
    # the response and appends to body;
    # `modal-toggle-always-fresh-value` removes any stale prior copy
    # first so DB state from the other tab (a newly-created suffix
    # Location) is picked up on reopen (#4304).
    def render_add_target_location_trigger(obs)
      link_to(
        :form_violations_action_add_target_location.l,
        target_location_modal_project_violations_path(
          project_id: @project.id, obs_id: obs.id
        ),
        class: "btn btn-default btn-xs",
        data: {
          modal: Views::Controllers::Projects::Violations::
                   TargetLocationForm.modal_id_for(obs),
          controller: "modal-toggle",
          action: "modal-toggle#showModal:prevent",
          modal_toggle_always_fresh_value: true
        }
      )
    end
  end
end
