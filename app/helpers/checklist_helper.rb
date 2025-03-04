# frozen_string_literal: true

module ChecklistHelper
  def checklist_name_link(taxon:, params:, data:)
    name, name_id, deprecated, synonym_id = taxon
    link = checklist_name_link_path(name_id, params)
    content = tag.i(name)
    content += " (#{data.counts[name]})"
    content += " *" if deprecated
    content += " +" if data.duplicate_synonyms.include?(synonym_id)

    tag.li { link_to(link) { content } }
  end

  def checklist_name_link_path(name_id, params)
    user, project, location, list = params
    prefix = if user
               "user:#{user.id}"
             elsif project
               "project:#{project.id}"
             elsif list
               "list:#{list.id}"
             end
    prefix += " location:#{location.id}" if location
    return name_path(name_id) unless prefix

    observations_path(pattern: "#{prefix} name:#{name_id} " \
                      "include_synonyms:false include_subtaxa:false")
  end
end
