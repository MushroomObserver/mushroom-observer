# frozen_string_literal: true

module ChecklistHelper
  def checklist_name_link(name:, user: nil, project: nil, list: nil,
                          counts: nil)
    link = checklist_name_link_path(name, user, project, list)
    content = tag.i(name[0])
    content += " (#{counts[name[0]]})" if counts
    content += " *" if name[2]

    tag.li { link_to(link) { content } }
  end

  def checklist_name_link_path(name, user, project, list)
    prefix = if user
               "user:#{user.id}"
             elsif project
               "project:#{project.id}"
             elsif list
               "list:#{list.id}"
             end
    return name_path(name[1]) unless prefix

    observations_path(pattern: "#{prefix} name:#{name[1]} " \
                      "include_synonyms:false include_subtaxa:false")
  end
end
