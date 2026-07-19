# frozen_string_literal: true

module Views::Controllers::Projects::Aliases
  # Phlex view for the project alias show page.
  class Show < Views::FullPageBase
    def initialize(project:, project_alias:)
      super()
      @project = project
      @project_alias = project_alias
    end

    def view_template
      add_project_banner(@project)
      container_class(:text)

      render_fields
      render_links
    end

    private

    def render_fields
      render_field("Name:", @project_alias.name)
      render_field("Target Type:",
                   @project_alias.target_type)
      render_field("Target:",
                   @project_alias.target.try(
                     :format_name
                   ))
    end

    def render_field(label, value)
      p do
        span(class: "font-weight-bold") { plain(label) }
        whitespace
        plain(value.to_s)
      end
    end

    def render_links
      pid = @project_alias.project_id
      a(href: edit_project_alias_path(
        project_id: pid, id: @project_alias.id
      )) { plain(:edit.ti) }
      plain(" | ")
      a(href: project_aliases_path) do
        plain(:back.ti)
      end
    end
  end
end
