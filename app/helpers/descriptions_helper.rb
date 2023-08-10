# frozen_string_literal: true

module DescriptionsHelper
  include Tabs::DescriptionsHelper

  def writer?(desc)
    desc.writer?(User.current) || in_admin_mode?
  end

  def is_admin?(desc)
    desc.is_admin?(User.current) || in_admin_mode?
  end

  def reader?(desc)
    desc.is_reader?(User.current) || in_admin_mode?
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
    links = description_mod_links(desc)
    tag.p(tag.span(title, class: "text-lg") + links.safe_join(" | "))
  end

  def description_mod_links(desc)
    links = []
    links << edit_button(target: desc) if writer?(desc)
    links << destroy_button(target: desc) if is_admin?(desc)
    links
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
      links = description_mod_links(desc)
      item += indent + "[" + links.safe_join(" | ") + "]" if links.any?
      item
    end

    # Add "fake" default public description if there aren't any public ones.
    if fake_default && obj.descriptions.none? { |d| d.source_type == :public }
      str = :description_part_title_public.t
      link = link_to(*create_description_link(obj))
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
    head = tag.b(:show_name_descriptions.t) + ": "
    head += link_to(*create_description_link(object))

    # Add title and maybe "no descriptions", wrapping it all up in paragraph.
    list = list_descriptions(object: object).map { |link| indent + link }
    any = list.any?
    list.unshift(head)
    list << indent + "show_#{type}_no_descriptions".to_sym.t unless any
    html = list.safe_join(safe_br)
    html = tag.div(html)

    add_list_of_projects(object, html, projects) if projects.present?
    html
  end

  # Show list of projects user is a member of.
  def add_list_of_projects(object, html, projects)
    return if projects.blank?

    head2 = :show_name_create_draft.t + ": "
    list = [head2] + projects.map do |project|
      item = link_to(*new_description_for_project_link(object, project))
      indent + item
    end
    html2 = list.safe_join(safe_br)
    html += tag.p(html2)
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
    tag.p(link_to(title, url))
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
