# frozen_string_literal: true

module ChecklistHelper
  def checklist_name_link(taxon:, user:, project:, list:, data:)
    name, name_id, deprecated, synonym_id = taxon
    link = checklist_name_link_path(name_id, user, project, list)
    content = tag.i(name)
    content += " (#{data.counts[name]})"
    content += " *" if deprecated
    content += " +" if data.duplicate_synonyms.include?(synonym_id)

    tag.li { link_to(link) { content } }
  end

  def checklist_name_link_path(name_id, user, project, list)
    prefix = if user
               "user:#{user.id}"
             elsif project
               "project:#{project.id}"
             elsif list
               "list:#{list.id}"
             end
    return name_path(name_id) unless prefix

    observations_path(pattern: "#{prefix} name:#{name_id} " \
                      "include_synonyms:false include_subtaxa:false")
  end
end
