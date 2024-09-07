# frozen_string_literal: true

module ChecklistHelper
  def checklist_name_link(name:, user: nil, project: nil, list: nil,
                          counts: nil)
    link = checklist_name_link_path(name, user, project, list)
    content = tag.i(name[0])
    content += " (#{counts[name[0]]})" if counts

    tag.li { link_to(link) { content } }
  end

  def checklist_name_link_path(name, project, list)
    if user
      observations_path(pattern: "user:#{user.id} name:#{name[1]}")
    elsif project
      observations_path(pattern: "project:#{project.id} name:#{name[1]}")
    elsif species_list
      observations_path(pattern: "list:#{list.id} name:#{name[1]}")
    else
      name_path(name[1])
    end
  end
end
