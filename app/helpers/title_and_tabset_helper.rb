# frozen_string_literal: true

# --------- Contextual Title and Navigation Links -----------------------------
#
#  Helpers for the page title and `tabs`, which are `link attribute arrays`
#  for building nav links (in the context of a page)
#
#  add_page_title(title)        # add content_for(:title)
#                                 and content_for(:document_title)
#  title_tag_contents           # text to put in html header <title>
#  add_index_title              # logic for index titles, with fallbacks
#  index_default_title          # logic for observations index default sort
#  add_pager_for(object)        # add a prev/next pager for an object (show)
#  link_next                    # link to next object
#  link_prev                    # link to prev object
#  add_tab_set(tabs)            # add content_for(:tab_set)
#  create_links_to(tabs)        # convert tabs -> link_to's / button_to's
#  create_link_to(tab)          # convert one tab into an HTML link or button
#  add_type_filters             # add content_for(:type_filters)
#  index_sorter                 # helper to render the sorter partial
#  add_interest_icons(user, object) # add content_for(:interest_icons)
#

module TitleAndTabsetHelper
  # sets both the html doc title and the title for the page (previously @title)
  def add_page_title(title)
    content_for(:title) do
      title
    end
    content_for(:document_title) do
      title_tag_contents(title)
    end
  end

  # contents of the <title> in html <head>
  def title_tag_contents(title, action: controller.action_name)
    if title.present?
      title.strip_html.unescape_html # removes tags and special chars
    elsif TranslationString.where(tag: "title_for_#{action}").present?
      :"title_for_#{action}".t
    else
      action.tr("_", " ").titleize
    end
  end

  # Special builder for index page titles.
  # These default to the query title, but may have several fallbacks, for
  # example, when users hit indexes with a bad or no query. The fallback
  # is determined by the "no_hits" arg. If indexes pass `no_hits: nil`,
  # the page will display the query title as the no_hits title.
  #
  # However, the helper allows indexes to pass a blank, non-nil `no_hits: ""`.
  # In this case, `index_default_title` will return a document_title of "Index"
  # but this helper will generate no title on the page. Currently this is the
  # expected behavior on Locations, Names, Observations and SpeciesLists tests.
  # It's debatable whether this is ideal UI, but i'm preserving the current
  # behavior for now.) - AN 2023
  def add_index_title(query, no_hits: nil)
    title = if !query
              ""
            elsif query.num_results.zero? && !no_hits.nil?
              no_hits
            else
              query.model.table_name.upcase.to_sym.l
            end
    add_page_title(title)
    add_query_filters(query)
  end

  def add_query_filters(query)
    return unless query&.params

    content_for(:filters) do
      tag.div(class: "small") do
        query.params.except(:by).compact_blank.each do |key, val|
          caption_one_filter_param(query, key, val)
        end
      end
    end
  end

  # Each param could be a boolean, a val, a set of vals,
  # a nested param with new key/vals, or a subquery.
  def caption_one_filter_param(query, key, val)
    concat(tag.div do
      if key.to_s.include?("_query")
        caption_string_for_subquery(query, key, val)
      elsif val.is_a?(Hash)
        caption_string_for_nested_params(query, key, val)
      else
        caption_string_for_val(query, key, val)
      end
    end)
  end

  # In the case of subqueries, treat them like a new query string.
  # Subquery params get { curly brackets }. The new query block is
  # inside the brackets and indented.
  def caption_string_for_subquery(query, label, hash)
    concat(tag.div("#{:"query_#{label}".l}: {"))
    concat(tag.div(class: "ml-3") do
      hash.each do |key, val|
        caption_one_filter_param(query, key, val)
      end
    end)
    concat(tag.div("}"))
  end

  # In the case of nested params, print them on one line separated by comma.
  # Nested params get [square brackets]
  def caption_string_for_nested_params(query, label, hash)
    len = hash.compact_blank.keys.size
    return if len.zero?

    concat(tag.span("#{:"query_#{label}".l}: "))
    hash.compact_blank.each_with_index do |(key, val), idx|
      caption_string_for_val(query, key, val)
      concat(tag.span(", ")) if idx < len - 1
    end
  end

  def caption_string_for_val(query, key, val)
    translation = :"query_#{key}".l
    if val == true
      concat(tag.span(translation))
    else
      concat(tag.span("#{translation}: ")) unless key == :lookup
      val = caption_lookup_for_val(query, key, val)
      concat(tag.b(val))
    end
  end

  def caption_lookup_for_val(query, key, val)
    return val unless captionable_query_params.include?(key)

    key = :names if key == :lookup
    send(:"caption_for_#{key}", query)
  end

  def captionable_query_params
    [:herbaria, :locations, :names, :projects, :project_lists,
     :species_lists, :by_users, :search_user, :lookup].freeze
  end

  def caption_for_herbaria(query)
    map_join_and_truncate(query, :herbaria, Herbarium, :name)
  end

  # NOTE: used in "Locations with Observations of {name}" - AN 2023
  def caption_for_locations(query)
    map_join_and_truncate(query, :locations, Location, :display_name)
  end

  def caption_for_names(query)
    tag.i(map_join_and_truncate(query, :lookup, Name, :text_name))
  end

  def caption_for_projects(query)
    map_join_and_truncate(query, :projects, Project, :title)
  end

  def caption_for_project_lists(query)
    map_join_and_truncate(query, :project_lists, Project, :title)
  end

  def caption_for_species_lists(query)
    map_join_and_truncate(query, :species_lists, SpeciesList, :title)
  end

  def caption_for_by_users(query)
    if query.params.deep_find(:by_users).size == 1
      User.find(query.params.deep_find(:by_users).first).legal_name
    else
      map_join_and_truncate(query, :by_users, User, :login)
    end
  end

  # takes a search string
  def caption_for_search_user(query)
    query.params.deep_find(:search_user)
  end

  # The max number of named items is hardcoded here to 3.
  def map_join_and_truncate(query, param, model, method)
    str = query.params.deep_find(param)[0..2].map do |val|
      # Integer(val) throws ArgumentError if val is not an integer.
      str = get_attribute_of_instance_by_integer(val, model, method)
    rescue ArgumentError # rubocop:disable Layout/RescueEnsureAlignment
      val
    end.join(", ")
    if str.length > 100
      str = "#{str[0...97]}..."
    elsif query.params.deep_find(param).length > 3
      str += ", ..."
    end
    str
  end

  def get_attribute_of_instance_by_integer(val, model, method)
    val = val.min if val.is_a?(Array)
    return val if val.is_a?(AbstractModel)

    model.find(Integer(val)).send(method)
  end

  # Used by several indexes that can be filtered based on user prefs
  def add_filter_help(filters_applied)
    return unless filters_applied

    content_for(:filter_help) do
      help_tooltip(
        "(#{:filtered.t})",
        title: :rss_filtered_mouseover.t, class: "filter-help"
      )
    end
  end

  # Show obs: observer's preferred naming. HTML here in case there is no naming
  def add_owner_naming(naming)
    return unless naming

    content_for(:owner_naming) do
      tag.h5(naming, id: "owner_naming")
    end
  end

  # Previous/next object links for show templates
  def add_pager_for(object)
    content_for(:prev_next_object) do
      render(partial: "application/content/prev_next_pager",
             locals: { object: object })
    end
  end

  # used by application/content/prev_next_pager
  # link to next object in query results
  def link_next(object)
    path = if object.type_tag == :rss_log
             send(:activity_log_path, object.id, flow: "next")
           else
             send(:"#{object.type_tag}_path", object.id, flow: "next")
           end
    link_with_query("#{:NEXT.t} »", path)
  end

  # link to previous object in query results
  def link_prev(object)
    path = if object.type_tag == :rss_log
             send(:activity_log_path, object.id, flow: "prev")
           else
             send(:"#{object.type_tag}_path", object.id, flow: "prev")
           end
    link_with_query("« #{:PREV.t}", path)
  end

  # Short-hand to render shared tab_set partial for a given set of tabs.
  def add_tab_set(tabs)
    return unless tabs

    links = create_links_to(tabs, { class: "d-block" })

    content_for(:tab_set) do
      render(partial: "application/content/tab_set", locals: { links: links })
    end
  end

  # Convert an array (of arrays) of link attributes into an array of HTML tabs
  # that may be either links or CRUD button_to's, for RHS tab set
  # Example
  # links = [
  #   ["text", "url", { class: "edit_form_link" }],
  #   [nil, article, { button: :destroy }]
  # ]
  # create_links_to(links) will make an array of the following HTML
  #   "<a href="url" class="edit_form_link">text</a>",
  #   "<form action='destroy'>" etc via destroy_button
  #   (The above array gives default button text and class)
  #
  # Allows passing an extra_args hash to be merged with each link's args
  #
  def create_links_to(tabs, extra_args = {})
    return [] unless tabs

    tabs.compact.map do |tab|
      create_link_to(tab, extra_args)
    end
  end

  # Unpacks the [text, url, args] array for a single link and figures out
  # which HTML to return for that type of link
  # Pass extra_args hash to modify the link/button attributes
  #
  def create_link_to(tab, extra_args = {})
    str, url, args = tab
    args ||= {}
    kwargs = merge_tab_args_with_extra_args(args, extra_args)
    # remove d-block from buttons, other links need it
    if args[:button].present? && kwargs[:class].present?
      kwargs[:class] = kwargs[:class].gsub("d-block", "").strip
    end

    case args[:button]
    when :destroy
      destroy_button(name: str, target: args[:target] || url, **kwargs)
    when :post
      post_button(name: str, path: url, **kwargs)
    when :put
      put_button(name: str, path: url, **kwargs)
    when :patch
      patch_button(name: str, path: url, **kwargs)
    else
      link_to(str, url, kwargs)
    end
  end

  # Make a hash of the kwargs that will be passed to link helper for HTML.
  # e.g. { data: { pileus: "awesome" }, id: "best_pileus", class: "hidden" }
  # Removes non-HTML args used by link_to/button helpers and merges with passed
  # extra_args, e.g. removes { name: "Click here to post", target: obs }
  # Note that class_names need to be concatenated, or the merge will overwrite.
  #
  def merge_tab_args_with_extra_args(args, extra_args)
    kwargs = args&.except(:button, :target)
    # blend in the class names that may come from the extra_args
    kwargs[:class] = class_names(kwargs[:class], extra_args[:class])
    # merge in other args from extra_args (will overwrite keys!)
    kwargs&.merge(extra_args&.except(:class))
  end

  # New style dropdown tabsets take array of tabs as hash of args,
  #   { name:, link:, class:, id:, etc. }
  #   not fully-formed `link_to` or `link_with_query`
  def add_dropdown_tab_set(tabs:, title: :LINKS.t)
    content_for(:dropdown_tab_set) do
      render(partial: "application/content/dropdown_tab_set",
             locals: { title: title, links: create_dropdown_links(tabs) })
    end
  end

  def create_dropdown_links(tabs)
    extra_args = {
      role: "menuitem",
      class: "dropdown-item"
    }
    create_links_to(tabs, extra_args)
  end

  def dropdown_link_options(args = {})
    args&.except(:name, :link, :button, :class) # prolly delete name and link
  end

  # type_filters, currently only used in RssLogsController#index
  def add_type_filters
    content_for(:type_filters) do
      render(partial: "application/content/type_filters")
    end
  end

  # The "Everything" tab
  def filter_for_everything(types)
    label = :rss_all.t
    link = activity_logs_path(params: { type: :all })
    help = { title: :rss_all_help.t, class: "filter-only" }
    types == ["all"] ? label : link_with_query(label, link, **help)
  end

  # A single tab
  def filter_for_type(types, type)
    label = :"rss_one_#{type}".t
    link = activity_logs_path(params: { type: type })
    help = { title: :rss_one_help.t(type: type.to_sym), class: "filter-only" }
    types == [type] ? label : link_with_query(label, link, **help)
  end

  # Conditionally dds a group of sorting links, for indexes, if relevant
  # These link back to the same index action, changing only the `by` param.
  #
  def add_sorter(query, sorts, link_all: false)
    return unless sorts && (query&.num_results&.> 1)

    content_for(:sorter) do
      links = create_sorting_links(query, sorts, link_all)

      render(partial: "application/content/sorter", locals: { links: links })
    end
  end

  # Make HTML buttons after adding relevant info to the raw sorts
  #
  # The terminology we're using to build these may be confusing:
  # `sorts` = the arrays of [by_param, :label.t] provided by index helpers.
  # `sort_links` = the same arrays, turned into [:label.t, path, id, active].
  # `links` = HTML links with all the fixin's, sent to the template
  #
  def create_sorting_links(query, sorts, link_all)
    sort_links = assemble_sort_links(query, sorts, link_all)

    sort_links.map do |title, path, identifier, active|
      classes = "btn btn-default"
      classes += " active" if active
      args = { class: class_names(classes, identifier) }
      args = args.merge(disabled: true) if active

      link_with_query(title, path, **args)
    end
  end

  # Add some info to the raw sorts: path, identifier, and if is current sort_by
  def assemble_sort_links(query, sorts, link_all)
    results = []
    this_by = (query.params[:by] || query.default_order).
              to_s.sub(/^reverse_/, "")

    sorts.each do |by, label|
      results << sort_link(label, query, by, this_by, link_all)
    end

    # Add a "reverse" button.
    results << sort_link(:sort_by_reverse.t, query, reverse_by(query, this_by),
                         this_by, link_all)
  end

  def reverse_by(query, this_by)
    if query.params[:by].to_s.start_with?("reverse_")
      this_by
    else
      "reverse_#{this_by}"
    end
  end

  # The final product of `assemble_sort_links`: an array of attributes
  # [text, action, identifier, active]
  def sort_link(label, query, by, this_by, link_all)
    path = { controller: query.model.show_controller,
             action: query.model.index_action,
             by: by }.merge(query_params)
    identifier = "#{query.model.to_s.pluralize.underscore}_by_#{by}_link"
    active = (!link_all && (by.to_s == this_by)) # boolean if current sort order

    [label.t, path, identifier, active]
  end

  # Draw the cutesy eye icons in the upper right side of screen.  It does it
  # by creating a "right" tab set.  Thus this must be called in the header of
  # the view and must not actually be rendered.  Typical usage would be:
  #
  #   # At top of view:
  #   <%
  #     # Specify the page's title.
  #     @title = "Page Title"
  #     add_interest_icons(@user, @object)
  #   %>
  #
  # This will cause the set of three icons to be rendered floating in the
  # top-right corner of the content portion of the page.

  def add_interest_icons(user, object)
    return unless user

    img1, img2, img3 = img_link_array(user, object)

    content_for(:interest_icons) do
      tag.div(img1 + safe_br + img2 + img3, class: "interest-eyes")
    end
  end

  # Array of image links which user can click to control getting email re object
  def img_link_array(user, object)
    type = object.type_tag
    case user.interest_in(object)
    when :watching
      img_links_when_watching(object, type)
    when :ignoring
      img_links_when_ignoring(object, type)
    else
      img_links_default(object, type)
    end
  end

  def img_links_when_watching(object, type)
    alt1 = :interest_watching.l(object: type.l)
    alt2 = :interest_default_help.l(object: type.l)
    alt3 = :interest_ignore_help.l(object: type.l)
    img1 = interest_icon_big("watch", alt1)
    img2 = interest_icon_small("halfopen", alt2)
    img3 = interest_icon_small("ignore", alt3)
    img2 = interest_link(img2, object, 0)
    img3 = interest_link(img3, object, -1)
    [img1, img2, img3]
  end

  def img_links_when_ignoring(object, type)
    alt1 = :interest_ignoring.l(object: type.l)
    alt2 = :interest_watch_help.l(object: type.l)
    alt3 = :interest_default_help.l(object: type.l)
    img1 = interest_icon_big("ignore", alt1)
    img2 = interest_icon_small("watch", alt2)
    img3 = interest_icon_small("halfopen", alt3)
    img2 = interest_link(img2, object, 1)
    img3 = interest_link(img3, object, 0)
    [img1, img2, img3]
  end

  def img_links_default(object, type)
    alt1 = :interest_watch_help.l(object: type.l)
    alt2 = :interest_ignore_help.l(object: type.l)
    img1 = interest_icon_small("watch", alt1)
    img2 = interest_icon_small("ignore", alt2)
    img1 = interest_link(img1, object, 1)
    img2 = interest_link(img2, object, -1)
    img3 = ""
    [img1, img2, img3]
  end

  # Create link to change interest state.
  def interest_link(label, object, state) # :nodoc:
    link_with_query(
      label,
      set_interest_path(id: object.id, type: object.class.name, state: state),
      data: { turbo_stream: true }
    )
  end

  # Create large icon image.
  def interest_icon_big(type, alt) # :nodoc:
    image_tag("#{type}2.png", alt: alt, class: "interest_big", title: alt)
  end

  # Create small icon image.
  def interest_icon_small(type, alt) # :nodoc:
    image_tag("#{type}3.png", alt: alt, class: "interest_small", title: alt)
  end

  # Generate an identifying class_name from the supplied tab method_name,
  # removing "_tab" from the method_name and replacing it with "_link"
  #   e.g., tab_id("map_observations_tab") returns "map_observations_link"
  # tab_id returns the original method_name if suffix "_tag" not found.
  # Class name is useful for identifying links or buttons in integration tests.
  #   Ruby notes: delete_suffix! returns nil if the suffix is not present.
  #   (The bang method is quicker than delete_suffix according to internet.)
  def tab_id(method_name)
    # "generic_tab_id"
    identifier = method_name.delete_suffix!("_tab")
    identifier ? "#{identifier}_link" : method_name
  end
end
