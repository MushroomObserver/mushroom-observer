# frozen_string_literal: true

module Views
  module Controllers
    module Projects
      # Phlex view for the project show page.
      # Replaces show.html.erb.
      class Show < Views::Base
        register_output_helper :add_show_title
        register_output_helper :add_project_banner
        register_output_helper :post_button, mark_safe: true
        register_output_helper :violations_button, mark_safe: true
        register_value_helper :permission!
        register_value_helper :container_class

        def initialize(project:, user:, drafts:, comments:)
          super()
          @project = project
          @user = user
          @drafts = drafts
          @comments = comments
        end

        def view_template
          add_show_title(@project.title, @project)
          add_project_banner(@project)
          container_class(:wide)

          render_list_search
          render_summary_panel
          render_actions
          render_comments
          render(Components::ObjectFooter.new(
                   user: @user, obj: @project
                 ))
        end

        private

        def render_list_search
          trusted_html(
            view_context.render(
              partial: "shared/list_search",
              locals: { object: @project }
            )
          )
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
              user_link(draft.user)
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

          post_button(
            name: :show_project_administer.l,
            class: action_button_class,
            path: project_administration_path(project_id: @project.id)
          )
        end

        def render_membership_buttons
          if @project.can_join?(@user)
            render_join_button
          elsif @project.member?(@user)
            render_member_buttons
          end
        end

        def render_join_button
          post_button(
            name: :show_project_join.l,
            class: action_button_class,
            path: project_members_path(
              project_id: @project.id,
              candidate: @user.id,
              target: :project_index
            )
          )
        end

        def render_member_buttons
          render_trust_settings_button
          render_leave_button if @project.can_leave?(@user)
          render_add_obs_button
        end

        def render_trust_settings_button
          modal_link_to(
            "trust_settings",
            :show_project_trust_settings.l,
            trust_modal_project_member_path(
              project_id: @project.id,
              candidate: @user.id
            ),
            { class: action_button_class }
          )
        end

        def render_leave_button
          put_button(
            name: :show_project_leave.t,
            class: action_button_class,
            path: project_member_path(
              project_id: @project.id,
              candidate: @user.id,
              target: :project_index
            )
          )
        end

        def render_add_obs_button
          modal_link_to(
            "add_obs",
            :change_member_add_obs.t,
            add_obs_modal_project_member_path(
              project_id: @project.id,
              candidate: @user.id
            ),
            { class: action_button_class }
          )
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

        def render_violations_button
          return unless @project.constraints?

          violations_button(@project)
        end

        def render_comments
          trusted_html(
            view_context.render(
              partial: "comments/comments_for_object",
              locals: {
                object: @project,
                comments: @comments,
                controls: @user,
                limit: nil
              }
            )
          )
        end
      end
    end
  end
end
