# frozen_string_literal: true

module DescriptionsHelper
  def writer?(desc)
    desc.writer?(User.current) || in_admin_mode?
  end

  def is_admin?(desc)
    desc.is_admin?(User.current) || in_admin_mode?
  end

  def reader?(desc)
    desc.is_reader?(User.current) || in_admin_mode?
  end

  # Create tabs for show_description page.
  def show_description_tabset(description:, pager: false)
    type = description.parent.type_tag
    admin = is_admin?(description)
    writer = writer?(description)
    # assemble HTML for "tabset" for show_{type}_description
    tabs = [
      show_parent_link(description, type),
      edit_description_link(description, writer),
      destroy_description_link(description, admin),
      clone_description_link(description),
      merge_description_link(description, admin),
      adjust_permissions_link(description, type, admin),
      make_default_link(description),
      project_link(description),
      publish_draft_link(description, type, admin)
    ].flatten.reject(&:empty?)
    tabset = { right: draw_tab_set(tabs) }
    tabset = tabset.merge(pager_for: description) if pager
    tabset
  end

  def show_parent_link(description, type)
    link_with_query(:show_object.t(type: type),
                    description.parent.show_link_args)
  end

  def new_description_link(object)
    add_button(
      name: :show_name_create_description.t,
      path: send("new_#{object.type_tag}_description_path",
                 params: { id: object.id, q: get_query_param }),
      class: "new_description_link_#{object.id}"
    )
  end

  def edit_description_link(description, writer)
    return unless writer

    edit_button(
      target: description, name: :show_description_edit.t
    )
  end

  def destroy_description_link(description, admin)
    return unless admin

    destroy_button(
      target: description, name: :show_description_destroy.t
    )
  end

  # The following need all the bells and whistles, because they're
  # special to descriptions and not built with the icon link helpers.

  # Clone is #new with parameters :clone, :id (name_id)
  def clone_description_link(description)
    link_to(
      { controller: description.show_controller,
        action: :new, id: description.parent_id,
        clone: description.id, q: get_query_param },
      class: "clone_description_link_#{description.id}",
      help: :show_description_clone_help.l,
      data: { toggle: "tooltip", placement: "top",
              title: :show_description_clone.t }
    ) do
      # concat(:show_description_clone.t)
      icon("fa-regular", "clone", class: "fa-lg")
    end
  end

  def merge_description_link(description, admin)
    return unless admin

    link_to(
      { controller: "#{description.show_controller}/merges",
        action: :new, id: description.id, q: get_query_param },
      class: "merge_description_link_#{description.id}",
      help: :show_description_merge_help.l,
      data: { toggle: "tooltip", placement: "top",
              title: :show_description_merge.t }
    ) do
      # concat(:show_description_merge.t)
      icon("fa-regular", "code-merge", class: "fa-lg")
    end
  end

  def move_description_link(description, admin)
    return unless admin

    parent_type = description.parent.type_tag.to_s
    link_to(
      { controller: "#{description.show_controller}/moves",
        action: :new, id: description.id, q: get_query_param },
      class: "move_description_link_#{description.id}",
      help: :show_description_move_help.l(parent: parent_type),
      data: { toggle: "tooltip", placement: "top",
              title: :show_description_move.t }
    ) do
      # concat(:show_description_move.t)
      icon("fa-regular", "file-export", class: "fa-lg")
    end
  end

  def adjust_permissions_link(description, type, admin)
    return unless admin && type == :name

    link_to(
      { controller: "#{description.show_controller}/permissions",
        action: :edit, id: description.id, q: get_query_param },
      class: "adjust_description_permissions_link_#{description.id}",
      help: :show_description_adjust_permissions_help.l,
      data: { toggle: "tooltip", placement: "top",
              title: :show_description_adjust_permissions.t }
    ) do
      # concat(:show_description_adjust_permissions.t)
      icon("fa-regular", "arrows-down-to-people", class: "fa-lg")
    end
  end

  def make_default_link(description)
    return unless description.public && User.current &&
                  (description.parent.description_id != description.id)

    put_button(
      name: :show_description_make_default.t,
      path: { controller: "#{description.show_controller}/defaults",
              action: :update, id: description.id, q: get_query_param },
      class: "make_description_default_link_#{description.id}",
      help: :show_description_make_default_help.l,
      data: { toggle: "tooltip", placement: "top",
              title: :show_description_make_default.t }
    ) do
      # concat(:show_description_make_default.t)
      icon("fa-regular", "star", class: "fa-lg")
    end
  end

  def project_link(description)
    return unless (description.source_type == :project) &&
                  (project = description.source_object)

    link_to(
      add_query_param(project.show_link_args),
      data: { toggle: "tooltip", placement: "top",
              title: :show_object.t(type: :project) }
    ) do
      # concat(:show_object.t(type: :project))
      icon("fa-regular", "people-arrows", class: "fa-lg")
    end
  end

  def publish_draft_link(description, type, admin)
    return unless admin && (type == :name) &&
                  (description.source_type != :public)

    put_button(
      name: :show_description_publish.t,
      path: { controller: "#{description.show_controller}/publish",
              action: :update, id: description.id,
              q: get_query_param },
      class: "publish_description_draft_link_#{description.id}",
      help: :show_description_publish_help.l,
      data: { toggle: "tooltip", placement: "top",
              title: :show_description_publish.t }
    ) do
      # concat(:show_description_publish.t
      icon("fa-regular", "check-to-slot", class: "fa-lg")
    end
  end

  # Header of the embedded description within a show_object page.
  #
  #   <%= show_embedded_description_title(desc, name) %>
  #
  #   # Renders something like this:
  #   <p>EOL Project Draft: Show | Edit | Destroy</p>
  #
  def show_embedded_description_title(desc)
    title = description_title(desc)
    writer = writer?(desc)
    admin = is_admin?(desc)
    links = [
      edit_description_link(desc, writer), # checks for writer
      destroy_description_link(desc, admin) # checks for admin
    ].compact.safe_join(" | ")
    content_tag(:p, tag.span(title) + links)
  end

  # Show list of name/location descriptions.
  def list_descriptions(object:, fake_default: false)
    user = User.current
    # Filter out empty descriptions (unless it's public or one you own).
    list = object.descriptions.includes(:user).select do |desc|
      desc.notes? || (desc.user == user) ||
        reviewer? || (desc.source_type == :public) || in_admin_mode?
    end

    list = sort_description_list(object, list)

    make_list_links(list, fake_default)
  end

  # Sort, putting the default one on top, followed by public ones, followed
  # by others ending in personal ones, sorting by "length" among groups.
  def sort_description_list(object, list)
    type_order = Description.all_source_types
    list.sort_by! do |x|
      [
        (x.id == object.description_id ? 0 : 1),
        type_order.index(x.source_type),
        -x.note_status[0],
        -x.note_status[1],
        description_title(x),
        x.id
      ]
    end

    list
  end

  # Turn each into a link to show_description, and add optional controls.
  def make_list_links(list, fake_default)
    list.map! do |desc|
      item = description_link(desc)
      writer = writer?(desc)
      admin  = is_admin?(desc)
      if writer || admin
        links = [
          edit_description_link(desc, writer), # checks for writer
          destroy_description_link(desc, admin) # checks for admin
        ].safe_join(" ")
        item += indent + links if links.present?
      end
      item
    end

    # Add "fake" default public description if there aren't any public ones.
    if fake_default && obj.descriptions.none? { |d| d.source_type == :public }
      str = :description_part_title_public.t
      link = link_with_query(
        :CREATE.t,
        { controller: desc.show_controller, action: :new, id: obj.id }
      )
      str += indent + "[" + link + "]"
      list.unshift(str)
    end

    list
  end

  # Show list of alternate descriptions for show_object page.
  #
  #   <%= show_alt_descriptions(object: name, projects: projects) %>
  #
  #   # Renders something like this:
  #   <p>
  #     Alternate Descriptions: Create Your Own
  #       Main Description
  #       EOL Project Draft
  #       Rolf's Draft (private)
  #   </p>
  #
  #   <p>
  #     Create New Draft For:
  #       Another Project
  #       One More Project
  #   </p>
  #
  def show_alt_descriptions(object:, projects: nil)
    type = object.type_tag

    # Show existing drafts, with link to create new one.
    head = content_tag(:b, :show_name_descriptions.t) + ": "
    head += new_description_link(object)

    # Add title and maybe "no descriptions", wrapping it all up in paragraph.
    list = list_descriptions(object: object).map { |link| indent + link }
    any = list.any?
    list.unshift(head)
    list << indent + "show_#{type}_no_descriptions".to_sym.t unless any
    html = list.safe_join(safe_br)
    html = content_tag(:div, html)

    add_list_of_projects(object, html, projects) if projects.present?
    html
  end

  # Show list of projects user is a member of.
  def add_list_of_projects(object, html, projects)
    return if projects.blank?

    head2 = :show_name_create_draft.t + ": "
    list = [head2] + projects.map do |project|
      item = link_to(
        project.title,
        { controller: "#{object.show_controller}/descriptions",
          action: :new, id: object.id, project: project.id,
          source: "project", q: get_query_param }
      )
      indent + item
    end
    html2 = list.safe_join(safe_br)
    html += content_tag(:p, html2)
    html
  end

  # Create a descriptive title for a Description.  Indicates the source and
  # very rough permissions (e.g. "public", "restricted", or "private").
  def description_title(desc)
    result = desc.partial_format_name

    # Indicate rough permissions.
    permit = if desc.parent.description_id == desc.id
               :default.l
             elsif desc.public
               :public.l
             elsif reader?(desc)
               :restricted.l
             else
               :private.l
             end
    result += " (#{permit})" unless /(^| )#{permit}( |$)/i.match?(result)

    t(result)
  end

  def name_section_link(title, data, query)
    return unless data && data != 0

    url = add_query_param(observations_path, query)
    content_tag(:p, link_to(title, url))
  end

  # Helpers for description forms

  # Source type options for description forms.
  def source_type_options_all
    options = []
    Description.all_source_types.each do |type|
      options << [:"form_description_source_#{type}".l, type]
    end
    options
  end

  def source_type_options_basic
    options = []
    Description.basic_source_types.each do |type|
      options << [:"form_description_source_#{type}".l, type]
    end
    options
  end
end
