# frozen_string_literal: true

# View Helpers for Projects
module ProjectsHelper
  def edit_project_alias_link(project_id, name, id)
    tag.span(id: "project_alias_#{id}") do
      modal_link_to(
        "project_alias_#{id}",
        *edit_project_alias_tab(project_id, name, id)
      )
    end
  end

  def new_project_alias_link(project_id, target_id, target_type)
    tag.span(id: "project_alias") do
      modal_link_to(
        "project_alias",
        *new_project_alias_tab(project_id, target_id, target_type)
      )
    end
  end
end
