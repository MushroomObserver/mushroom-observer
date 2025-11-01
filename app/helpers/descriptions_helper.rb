# frozen_string_literal: true

# Added while getting rid of User.current references
module DescriptionsHelper
  include Tabs::DescriptionsHelper

  # def writer?(desc)
  #   desc.writer?(User.current) || in_admin_mode?
  # end

  def user_writer?(user, desc)
    desc.writer?(user) || in_admin_mode?
  end

  def is_admin?(desc)
    desc.is_admin?(User.current) || in_admin_mode?
  end

  def user_is_admin?(user, desc)
    desc.is_admin?(user) || in_admin_mode?
  end

  # def reader?(desc)
  #   desc.is_reader?(User.current) || in_admin_mode?
  # end

  def user_reader?(user, desc)
    desc.is_reader?(user) || in_admin_mode?
  end

  # Header of the embedded description within a show_object page.
  #
  #   <%= show_embedded_description_title(user, desc, name) %>
  #
  #   # Renders something like this:
  #   <p>EOL Project Draft: Show | Edit | Destroy</p>

  def description_mod_links(user, desc, type)
    links = []
    (text, path, args) = *edit_description_tab(user, desc, type)
    links << icon_link_to(text, path, **args) if user_writer?(user, desc)
    links << destroy_button(target: desc, icon: :delete) if user_is_admin?(
      user, desc
    )
    links
  end

  # Show list of name/location descriptions.
  def list_descriptions(user:, object:, type:,
                        fake_default: false, current: nil)
    # Filter out empty descriptions (unless it's public or one you own).
    list = object.descriptions.includes(:user).select do |desc|
      desc.notes? || (desc.user == user) ||
        reviewer? || (desc.source_type == :public) || in_admin_mode?
    end

    list = sort_description_list(user, object, list)

    # Don't make a link if we're on that description's page (current)
    make_list_links(user, list, type, fake_default, current)
  end

  # Sort, putting the default one on top, followed by public ones, followed
  # by others ending in personal ones, sorting by "length" among groups.
  def sort_description_list(user, object, list)
    type_order = Description::ALL_SOURCE_TYPES
    list.sort_by! do |x|
      [
        (x.id == object.description_id ? 0 : 1),
        type_order.index(x.source_type),
        -x.note_status[0],
        -x.note_status[1],
        description_title(user, x),
        x.id
      ]
    end

    list
  end

  # Turn each into a link to show_description, and add optional controls.
  # (or if we're on that description's page currently, just the desc title)
  def make_list_links(user, list, type, fake_default, current = nil)
    list.map! do |desc|
      if desc == current
        item = description_title(user, desc)
      else
        item = description_link(user, desc)
        links = description_mod_links(user, desc, type)
        # disable cop -- lh side is a safe buffer, not a string
        item += indent + "[ " + links.safe_join(" | ") + " ]" if links.any? # rubocop:disable Style/StringConcatenation
      end
      item
    end

    # Add "fake" default public description if there aren't any public ones.
    if fake_default && obj.descriptions.none? { |d| d.source_type == :public }
      str = :description_part_title_public.t
      link = link_to(*create_description_tab(obj))
      # disable cop because lh side (indent) is a safe buffer, not a string
      str += indent + "[ " + link + " ]" # rubocop:disable Style/StringConcatenation
      list.unshift(str)
    end

    list
  end

  # Details of a description for a show_description page.
  def show_description_details(description, versions, user)
    parent = description.parent
    type = parent.type_tag

    read = if description.reader_groups.include?(UserGroup.all_users)
             :public.l
           elsif in_admin_mode? || description.is_reader?(user)
             :restricted.l
           else
             :private.l
           end

    write = if description.writer_groups.include?(UserGroup.all_users)
              :public.l
            elsif in_admin_mode? || description.writer?(user)
              :restricted.l
            else
              :private.l
            end

    tag.div do
      [
        ["#{:TITLE.l}:", description_title(user, description)].safe_join(" "),
        [
          "#{type.to_s.upcase.to_sym.t}:",
          link_to(parent.format_name.t, parent.show_link_args)
        ].safe_join(" "),
        "#{:show_description_read_permissions.l}: #{read}",
        "#{:show_description_write_permissions.l}: #{write}",
        show_previous_version(description, versions)
      ].safe_join(safe_br)
    end
  end

  def show_description_export_and_review(desc)
    capture do
      concat(tag.div(show_description_export_status(desc)))
      concat(tag.div(show_name_description_review(desc)))
    end
  end

  def show_description_export_status(desc)
    reviewer? ? export_status_controls(desc) : ""
  end

  def show_name_description_review(desc)
    return unless desc.parent.type_tag == :name

    html = []
    html << show_name_description_review_status(desc)
    html << show_name_description_latest_review(desc) if desc.reviewer
    html.safe_join
  end

  def show_name_description_review_status(desc)
    tag.div do
      concat("#{:show_name_content_status.l}: ")
      concat(review_as_string(desc.review_status))
      concat(show_name_description_review_ui(desc))
    end
  end

  def show_name_description_review_ui(desc)
    return unless reviewer?

    tag.span(class: "reviewers-only") do
      concat(tag.span(" | "))
      concat(%w[unvetted vetted inaccurate].map do |w|
        put_button(name: :"review_#{w}".l,
                   path: review_status_name_description_path(desc.id, value: w))
      end.safe_join(tag.span(" | ")))
    end
  end

  def show_name_description_latest_review(desc)
    tag.span(class: "help-note") do
      # disable cop -- lh side is a safe buffer, not a string
      indent + "(" + :show_name_latest_review.t( # rubocop:disable Style/StringConcatenation
        date: desc.last_review ? desc.last_review.web_time : :UNKNOWN.l,
        user: user_link(desc.reviewer, desc.reviewer.login)
      ) + ")"
    end
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
  # Pass `current` to avoid linking to the current description on show desc page
  def show_alt_descriptions(user:, object:, projects: nil, current: nil)
    type = object.type_tag

    # Show existing drafts, with link to create new one.
    # disable cop -- lh side is a safe buffer, not a string
    head = tag.b(:show_name_descriptions.l) + ": " # rubocop:disable Style/StringConcatenation
    head += icon_link_to(*create_description_tab(object, type))

    # Add title and maybe "no descriptions", wrapping it all up in paragraph.
    list = list_descriptions(user:, object:, type:, current:).map do |link|
      indent + link
    end
    any = list.any?
    list.unshift(head)
    list << indent + :"show_#{type}_no_descriptions".t unless any
    html = list.safe_join(safe_br)
    html = tag.div(html)

    add_list_of_projects(object, type, html, projects) if projects.present?
    html
  end

  # Show list of projects user is a member of.
  def add_list_of_projects(object, type, html, projects)
    return if projects.blank?

    head2 = "#{:show_name_create_draft.l}: "
    list = [head2] + projects.map do |project|
      item = link_to(*new_description_for_project_tab(object, type, project))
      indent + item
    end
    html2 = list.safe_join(safe_br)
    html += tag.p(html2)
    html
  end

  def show_description_authors_and_editors(desc, versions, user)
    tag.div(class: "text-center") do
      concat(
        show_authors_and_editors(obj: desc, versions: versions, user: user)
      )
      if desc.license
        concat(render(partial: "shared/form_license_badge",
                      locals: { license: desc.license }))
      end
    end
  end

  # Wrap description title in link to show_description.
  #
  #   Description: <%= description_link(user, name.description) %>
  #
  def description_link(user, desc)
    result = description_title(user, desc)
    return result if result.match?("(#{:private.t})$")

    link_to(result, desc.show_link_args, class: "description_link_#{desc.id}")
  end

  # Create a descriptive title for a Description.  Indicates the source and
  # very rough permissions (e.g. "public", "restricted", or "private").
  def description_title(user, desc)
    result = desc.partial_format_name

    # Indicate rough permissions.
    permit = if desc.parent.description_id == desc.id
               :default.l
             elsif desc.public
               :public.l
             elsif user_reader?(user, desc)
               :restricted.l
             else
               :private.l
             end
    result += " (#{permit})" unless /(^| )#{permit}( |$)/i.match?(result)

    t(result)
  end

  # Helpers for description forms

  # Source type options for description forms.
  def source_type_options_all
    Description::ALL_SOURCE_TYPES.map do |type|
      [:"form_description_source_#{type}".l, type]
    end
  end

  def source_type_options_basic
    Description::BASIC_SOURCE_TYPES.map do |type|
      [:"form_description_source_#{type}".l, type]
    end
  end
end
