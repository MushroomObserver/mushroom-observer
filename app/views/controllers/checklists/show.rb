# frozen_string_literal: true

module Views
  module Controllers
    module Checklists
      # Phlex view for the checklist page. Replaces show.html.erb.
      class Show < Views::Base
        register_output_helper :add_project_banner
        register_output_helper :add_page_title
        register_output_helper :add_context_nav
        register_value_helper :container_class
        register_value_helper :checklist_show_title
        register_value_helper :checklist_show_tabs

        def initialize(data:, context:)
          super()
          @data = data
          @context = context
        end

        def view_template
          render_page_chrome
          render_target_names_widget if @context.admin?
          render(Components::Checklist::Contents.new(
                   data: @data, context: @context
                 ))
        end

        private

        def render_page_chrome
          container_class(:full)
          add_project_banner(@context.project) if @context.project
          add_page_title(
            checklist_show_title(user: @context.show_user,
                                 list: @context.species_list)
          )
          add_context_nav(
            checklist_show_tabs(user: @context.show_user,
                                list: @context.species_list)
          )
        end

        def render_target_names_widget
          render(Components::Projects::TargetNamesWidget.new(
                   project: @context.project
                 ))
        end
      end
    end
  end
end
