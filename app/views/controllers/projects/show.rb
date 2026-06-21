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

    def render_administer_button
      return unless @user&.admin && !@project.is_admin?(@user)

      render(Components::Button::Post.new(
               name: :show_project_administer.l,
               target: project_administration_path(project_id: @project.id),
               size: :lg, class: "my-2 mr-2"
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
      render(Components::Button::Post.new(
               name: :show_project_join.l,
               target: project_members_path(
                 project_id: @project.id,
                 candidate: @user.id,
                 target: :project_index
               ),
               size: :lg, class: "my-2 mr-2"
             ))
    end

    def render_member_buttons
      render_trust_settings_button
      render_leave_button if @project.can_leave?(@user)
      render_add_obs_button
    end

    def render_trust_settings_button
      render(Components::Button::ModalToggle.new(
               name: :show_project_trust_settings.l,
               target: trust_modal_project_member_path(
                 project_id: @project.id, candidate: @user.id
               ),
               modal_id: "trust_settings",
               size: :lg, class: "my-2 mr-2"
             ))
    end

    def render_leave_button
      render(Components::Button::Put.new(
               name: :show_project_leave.t,
               target: project_member_path(
                 project_id: @project.id,
                 candidate: @user.id,
                 target: :project_index
               ),
               size: :lg, class: "my-2 mr-2"
             ))
    end

    def render_add_obs_button
      render(Components::Button::ModalToggle.new(
               name: :change_member_add_obs.t,
               target: add_obs_modal_project_member_path(
                 project_id: @project.id, candidate: @user.id
               ),
               modal_id: "add_obs",
               size: :lg, class: "my-2 mr-2"
             ))
    end

    def render_admin_links
      return if permission?(@project)

      render(Components::Button::Get.new(
               name: :show_project_admin_request.l,
               target: new_project_admin_request_path(
                 project_id: @project.id
               ),
               size: :lg, class: "my-2 mr-2"
             ))
    end

    # Explicit String target because the violations route uses
    # `:project_id` (not `:id`), so Button::Get can't auto-build the
    # path from a model. See the `violations_route_endpoint_smell`
    # memory for the planned fix.
    def render_violations_button
      return unless @project.constraints?

      count = @project.count_violations
      render(Components::Button::Get.new(
               name: "#{count} #{:CONSTRAINT_VIOLATIONS.l}",
               target: project_violations_path(project_id: @project.id),
               style: count.positive? ? :warning : :default,
               size: :lg,
               class: "my-2 mr-2"
             ))
    end

    def render_comments
      render(::Views::Controllers::Comments::CommentsForObject.new(
               object: @project, comments: @comments.to_a, user: @user,
               editable: @user.present?, limit: nil
             ))
    end
  end
end
