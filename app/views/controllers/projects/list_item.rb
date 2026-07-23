# frozen_string_literal: true

# Inner content of one row in the projects index list-group. The
# `<div class="list-group-item …">` wrapper is supplied by the
# caller (`Components::ListGroup`);
# this class only emits the two-column body (id badge + title /
# meta column).
module Views::Controllers::Projects
  class ListItem < Views::Base
    def initialize(project:)
      super()
      @project = project
    end

    def view_template
      div(class: "text-larger") do
        IDBadge(object: @project, size: :md)
      end
      div do
        render_title_row
        render_meta_row
      end
    end

    private

    def render_title_row
      div do
        a(href: project_path(@project.id)) do
          span(class: "h4") { trusted_html(@project.title.t) }
        end
        if @project.open_membership
          whitespace
          span(class: "ml-4") { plain("(#{:open.ti})") }
        end
      end
    end

    def render_meta_row
      div do
        small { plain("#{@project.created_at.web_time}:") }
        whitespace
        Link(type: :user, user: @project.user)
      end
    end
  end
end
