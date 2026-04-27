# frozen_string_literal: true

module ChecklistHelper
  def checklist_name_link(taxon:, data:, context:,
                          link_to_name_page: false)
    name, name_id, deprecated, synonym_id = taxon
    link = if link_to_name_page
             name_path(name_id)
           else
             checklist_name_link_path(name_id, context.link_params)
           end
    content = checklist_name_content(name, name_id, deprecated,
                                     synonym_id, data)
    li_class = target_name?(name_id, data) ? "checklist-target-name" : nil

    tag.li(class: li_class) do
      link_to(link) { content } +
        checklist_target_remove_button(context, name_id)
    end
  end

  def checklist_name_content(name, _name_id, deprecated,
                             synonym_id, data)
    content = tag.i(name)
    content += " (#{data.counts[name]})"
    content += " *" if deprecated
    content += " +" if data.duplicate_synonyms&.include?(synonym_id)
    content
  end

  def checklist_target_remove_button(context, name_id)
    return "".html_safe unless context.admin?
    return "".html_safe unless target_name_for_project?(context.project,
                                                        name_id)

    button_to(
      project_target_name_path(project_id: context.project.id, id: name_id),
      method: :delete,
      class: "btn btn-link text-danger p-0 ml-1",
      form: { data: {
        turbo: true,
        turbo_confirm: :project_target_name_confirm_remove.t(
          name: Name.safe_find(name_id)&.text_name
        )
      } }
    ) { tag.span(class: "glyphicon glyphicon-remove") }
  end

  def target_name?(name_id, data)
    data.respond_to?(:target_name_ids) &&
      data.target_name_ids.include?(name_id)
  end

  def target_name_for_project?(project, name_id)
    project.target_name_ids.include?(name_id)
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
