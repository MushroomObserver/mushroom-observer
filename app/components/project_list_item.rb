# frozen_string_literal: true

# Renders a single project in a list-group.
# Replaces _project.html.erb partial.
class Components::ProjectListItem < Components::Base
  def initialize(project:)
    super()
    @project = project
  end

  def view_template
    div(class: "list-group-item d-flex align-items-start") do
      div(class: "text-larger") do
        show_title_id_badge(@project, "rss-id mr-4")
      end
      div do
        render_title_row
        render_meta_row
      end
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
        span(class: "ml-4") { plain("(#{:OPEN.t})") }
      end
    end
  end

  def render_meta_row
    div do
      small { plain("#{@project.created_at.web_time}:") }
      whitespace
      user_link(@project.user)
    end
  end
end
