# frozen_string_literal: true

# Phlex view for the checklist page. Replaces show.html.erb.
module Views::Controllers::Checklists
  class Show < Views::FullPageBase
    def initialize(data:, context:)
      super()
      @data = data
      @context = context
    end

    def view_template
      render_page_chrome
      render_target_names_widget if @context.admin?
      # Sibling reference in the `Views::Controllers::Checklists`
      # module — resolves to `Checklists::Contents`.
      render(Contents.new(data: @data, context: @context))
    end

    private

    def render_page_chrome
      container_class(:full)
      add_project_banner(@context.project) if @context.project
      add_page_title(checklist_show_title)
      list = @context.species_list
      add_context_nav(
        Tab::Checklist::ShowActions.new(
          user: @context.show_user, list: list,
          permission: list ? permission?(list) : false
        )
      )
    end

    def checklist_show_title
      user = @context.show_user
      list = @context.species_list
      if user
        :checklist_for_user_title.t(user: user.legal_name)
      elsif list
        :checklist_for_species_list_title.t(list: list.title)
      else
        :checklist_for_site_title.t
      end
    end

    def render_target_names_widget
      render(Views::Controllers::Projects::TargetNames::Form.new(
               project: @context.project
             ))
    end
  end
end
