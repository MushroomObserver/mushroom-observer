# frozen_string_literal: true

module Views::Controllers::Projects
  # Phlex view for the project show page.
  class Show < Views::FullPageBase
    def initialize(project:, user:, drafts:, comments:, object_names:)
      super()
      @project = project
      @user = user
      @drafts = drafts
      @comments = comments
      @object_names = object_names
    end

    def view_template
      add_show_title(@project)
      add_project_banner(@project)
      container_class(:wide)

      render_list_search
      render_summary_panel
      render_actions
      render_comments
      render(Views::Layouts::ObjectFooter.new(
               user: @user, obj: @project
             ))
    end

    private

    def render_list_search
      render(Components::ListGroup::Search.new(
               object: @project,
               object_names: @object_names,
               project: @project
             ))
    end

    def render_summary_panel
      render(Components::Panel.new(
               panel_id: "project_summary"
             )) do |panel|
        panel.with_body do
          render_summary_body
        end
      end
    end

    def render_summary_body
      p { trusted_html(@project.summary.to_s.tpl) }
      render_drafts if @drafts.any?
      render_created_at
    end

    def render_drafts
      p do
        b { plain("#{:show_project_drafts.t}:") }
        whitespace
        plain(@drafts.length.to_s)
        br
        render_draft_list
      end
    end

    def render_draft_list
      div(class: "ml-3") do
        @drafts.each do |draft|
          a(href: name_description_path(draft.id)) do
            trusted_html(draft.name&.display_name&.t)
          end
          plain(" (")
          render(Components::Link::Object::User.new(user: draft.user))
          plain(")")
          br
        end
      end
    end

    def render_created_at
      p do
        strong { plain("#{:show_project_created_at.l}:") }
        whitespace
        plain(@project.created_at.web_date)
      end
    end

    def render_actions
      div(id: "project_join_trust_edit", class: "mb-4") do
        render_membership_buttons
        render_administer_button
        render_admin_links
        render_violations_button
      end
    end

    # Shared classes for every button in render_actions so the row reads
    # consistently at narrow and wide viewports. Issue #4145.
    def action_button_class
      "btn btn-default btn-lg my-2 mr-2"
    end

    def render_administer_button
      return unless @user&.admin && !@project.is_admin?(@user)

      render(Components::CRUDButton::Post.new(
               name: :show_project_administer.l,
               target: project_administration_path(project_id: @project.id),
               class: action_button_class
             ))
    end

    def render_membership_buttons
      if @project.can_join?(@user)
        render_join_button
      elsif @project.member?(@user)
        render_member_buttons
      end
    end

    def render_join_button
      render(Components::CRUDButton::Post.new(
               name: :show_project_join.l,
               target: project_members_path(
                 project_id: @project.id,
                 candidate: @user.id,
                 target: :project_index
               ),
               class: action_button_class
             ))
    end

    def render_member_buttons
      render_trust_settings_button
      render_leave_button if @project.can_leave?(@user)
      render_add_obs_button
    end

    def render_trust_settings_button
      render(Components::Link::Modal.new(
               "trust_settings",
               :show_project_trust_settings.l,
               trust_modal_project_member_path(
                 project_id: @project.id,
                 candidate: @user.id
               ),
               class: action_button_class
             ))
    end

    def render_leave_button
      render(Components::CRUDButton::Put.new(
               name: :show_project_leave.t,
               target: project_member_path(
                 project_id: @project.id,
                 candidate: @user.id,
                 target: :project_index
               ),
               class: action_button_class
             ))
    end

    def render_add_obs_button
      render(Components::Link::Modal.new(
               "add_obs",
               :change_member_add_obs.t,
               add_obs_modal_project_member_path(
                 project_id: @project.id,
                 candidate: @user.id
               ),
               class: action_button_class
             ))
    end

    def render_admin_links
      return if permission?(@project)

      a(
        href: new_project_admin_request_path(
          project_id: @project.id
        ),
        class: action_button_class
      ) { plain(:show_project_admin_request.l) }
    end

    # Not a CRUDButton candidate — count-badge link with `btn-warning`
    # styling when constraints are violated, not a standard action button.
    def render_violations_button
      return unless @project.constraints?

      count = @project.count_violations
      btn_type = count.positive? ? "btn-warning" : "btn-default"
      link_to(
        "#{count} #{:CONSTRAINT_VIOLATIONS.l}",
        project_violations_path(project_id: @project.id),
        class: "btn btn-lg #{btn_type} my-2 mr-2"
      )
    end

    def render_comments
      render(::Views::Controllers::Comments::CommentsForObject.new(
               object: @project, comments: @comments.to_a, user: @user,
               editable: @user.present?, limit: nil
             ))
    end
  end
end
