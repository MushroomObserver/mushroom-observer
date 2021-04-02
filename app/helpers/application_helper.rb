# frozen_string_literal: true

#
#  = Application Helpers
#
#  Methods available to all templates in the application:
#
#  safe_br                      # <br/>,html_safe
#  safe_empty
#  safe_nbsp
#  escape_html                  # Return escaped HTML
#
#  --- links and buttons ----
#
#  link_to_coerced_query        # link to query coerced into different model
#  link_with_query              # link_to with query params
#  link_next                    # link to next object
#  link_prev                    # link to prev object
#  destroy_button               # button to destroy object
#  post_button                  # button to post to a path
#  create_link                  # convert links into list of tabs
#
#  --------------------------
#
#  indent                       # in-lined white-space element of n pixels
#  content_tag_if
#  content_tag_unless
#  add content_help             # help text viewable on mouse-over
#  add_header                   # add to html header from within view
#  make_table                   # make table from list of arrays
#  reload_with_args             # add args to url that got us to this page
#  add_args_to_url              # change params of arbitrary url
#  url_after_delete             # url to return to after deleting object
#  get_next_id
#  textilize_without_paragraph  # override Rails method of same name
#  textilize                    # override Rails method of same name
#  custom_file_field            # stylable file input field with
#                               # client-side size validation
#  date_select_opts
#  title_tag_contents           # text to put in html header <title>
#
module ApplicationHelper
  include AutocompleteHelper
  include DescriptionHelper
  include ExporterHelper
  include FooterHelper
  include JavascriptHelper
  include LocalizationHelper
  include MapHelper
  include ObjectLinkHelper
  include TabsHelper
  include ThumbnailHelper
  include VersionHelper

  def safe_empty
    "".html_safe
  end

  def safe_br
    "<br/>".html_safe
  end

  def safe_nbsp
    "&nbsp;".html_safe
  end

  # Return escaped HTML.
  #
  #   "<i>X</i>"  -->  "&lt;i&gt;X&lt;/i&gt;"
  def escape_html(html)
    h(html.to_str)
  end

  # --------- links and buttons ------------------------------------------------

  # Call link_to with query params added.
  def link_with_query(name = nil, options = nil, html_options = nil)
    link_to(name, add_query_param(options), html_options)
  end

  # Take a query which can be coerced into a different model, and create a link
  # to the results of that coerced query.  Return +nil+ if not coercable.
  def link_to_coerced_query(query, model)
    link = coerced_query_link(query, model)
    return nil unless link

    link_to(*link)
  end

  # link to next object in query results
  def link_next(object)
    path = if object.type_tag == :herbarium
             herbarium_path(object.id, flow: "next")
           else
             { controller: object.show_controller,
               action: object.next_action, id: object.id }
           end
    link_with_query("#{:FORWARD.t} »", path)
  end

  # link to previous object in query results
  def link_prev(object)
    path = if object.type_tag == :herbarium
             herbarium_path(object.id, flow: "prev")
           else
             { controller: object.show_controller,
               action: object.prev_action, id: object.id }
           end
    link_with_query("« #{:BACK.t}", path)
  end

  # button to destroy object
  # Used instead of link because DESTROY link requires js
  # Sample usage:
  #   destroy_button(object: article)
  #   destroy_button(object: term, :destroy_object.t(type: :glossary_term)
  #   destroy_button(
  #     name: :destroy_object.t(type: :herbarium),
  #     target: herbarium_path(@herbarium, back: url_after_delete(@herbarium))
  #   )
  def destroy_button(target:, name: :DESTROY.t)
    options = if target.is_a?(String)
                target
              else
                { action: "destroy", id: target.id }
              end
    button_to(
      name, options, method: :delete, data: { confirm: :are_you_sure.t }
    )
  end

  # POST to a path; used instead of a link because POST link requires js
  # post_button(name: herbarium.name.t,
  #             path: herbaria_merges_path(that: @merge.id,this: herbarium.id))
  def post_button(name:, path:, confirm: false)
    button_to(
      name, path, method: :post, data: { confirm: :are_you_sure.t }
    )
  end

  # Convert @links in index views into a list of tabs for RHS tab set.
  def create_links(links)
    return [] unless links

    links.reject(&:nil?).map { |str, url| link_to(str, url) }
  end

  # ----------------------------------------------------------------------------

  # Create an in-line white-space element approximately the given width in
  # pixels.  It should be non-line-breakable, too.
  def indent(count = 10)
    "<span style='margin-left:#{count}px'>&nbsp;</span>".html_safe
  end

  def content_tag_if(condition, name, content_or_options_with_block = nil,
                     options = nil, escape = true, &block)
    return unless condition

    content_tag(name, content_or_options_with_block, options, escape, &block)
  end

  def content_tag_unless(condition, name, content_or_options_with_block = nil,
                         options = nil, escape = true, &block)
    content_tag_if(!condition, name, content_or_options_with_block,
                   options, escape, &block)
  end

  # Wrap an html object in '<span title="blah">' tag.  This has the effect of
  # giving it context help (mouse-over popup) in most modern browsers.
  #
  #   <%= add_context_help(link, "Click here to do something.") %>
  #
  def add_context_help(object, help)
    content_tag(:span, object, title: help, data: { toggle: "tooltip" })
  end

  # Add something to the header from within view.  This can be called as many
  # times as necessary -- the application layout will mash them all together
  # and stick them at the end of the <tt>&gt;head&lt;/tt> section.
  #
  #   <%
  #     add_header(GMap.header)       # adds GMap general header
  #     gmap = make_map(@locations)
  #     add_header(finish_map(gmap))  # adds map-specific header
  #   %>
  #
  def add_header(str)
    @header ||= safe_empty
    @header += str
  end

  # Create a table out of a list of Arrays.
  #
  #   make_table([[1,2],[3,4]])
  #
  # Produces:
  #
  #   <table>
  #     <tr>
  #       <td>1</td>
  #       <td>2</td>
  #     </tr>
  #     <tr>
  #       <td>3</td>
  #       <td>4</td>
  #     </tr>
  #   </table>
  #
  def make_table(rows, table_opts = {}, tr_opts = {}, td_opts = {})
    content_tag(:table, table_opts) do
      rows.map do |row|
        make_row(row, tr_opts, td_opts) + make_line(row, td_opts)
      end.safe_join
    end
  end

  def make_row(row, tr_opts = {}, td_opts = {})
    content_tag(:tr, tr_opts) do
      if !row.is_a?(Array)
        row
      else
        row.map do |cell|
          make_cell(cell, td_opts)
        end.safe_join
      end
    end
  end

  def make_cell(cell, td_opts = {})
    content_tag(:td, cell.to_s, td_opts)
  end

  def make_line(_row, td_opts)
    colspan = td_opts[:colspan]
    if colspan
      content_tag(:tr, class: "MatrixLine") do
        content_tag(:td, tag(:hr), class: "MatrixLine", colspan: colspan)
      end
    else
      safe_empty
    end
  end

  # Take URL that got us to this page and add one or more parameters to it.
  # Returns new URL.
  #
  #   link_to("Next Page", reload_with_args(page: 2))
  #
  def reload_with_args(new_args)
    uri = request.url.sub(%r{^\w+:/+[^/]+}, "")
    add_args_to_url(uri, new_args)
  end

  # Take an arbitrary URL and change the parameters. Returns new URL. Should
  # even handle the fancy "/object/id" case. (Note: use +nil+ to mean delete
  # -- i.e. <tt>add_args_to_url(url, old_arg: nil)</tt> deletes the
  # parameter named +old_arg+ from +url+.)
  #
  #   url = url_for(action: "blah", ...)
  #   new_url = add_args_to_url(url, arg1: :val1, arg2: :val2, ...)
  #
  def add_args_to_url(url, new_args)
    new_args = new_args.clone
    args = {}

    # Garbage in, garbage out...
    return url unless url.valid_encoding?

    # Parse parameters off of current URL.
    addr, parms = url.split("?")
    for arg in parms ? parms.split("&") : []
      var, val = arg.split("=")
      next unless var && var != ""

      var = CGI.unescape(var)
      # See note below about precedence in case of redundancy.
      args[var] = val unless args.key?(var)
    end

    # Deal with the special "/xxx/id" case.
    if %r{/(\d+)$}.match?(addr)
      new_id = new_args[:id] || new_args["id"]
      addr.sub!(/\d+$/, new_id.to_s) if new_id
      new_args.delete(:id)
      new_args.delete("id")
    end

    # Merge in new arguments, deleting where new values are nil.
    for var in new_args.keys
      val = new_args[var]
      var = var.to_s
      if val.nil?
        args.delete(var)
      elsif val.is_a?(ActiveRecord::Base)
        args[var] = val.id.to_s
      else
        args[var] = CGI.escape(val.to_s)
      end
    end

    # Put it back together.
    return addr if args.keys.empty?

    addr + "?" + args.keys.sort.map do |k|
      CGI.escape(k) + "=" + (args[k] || "")
    end.join("&")
  end

  # Returns URL to return to after deleting an object.  Can't just return to
  # the index, because we'd prefer to return to the correct page in the index,
  # but to do that we need to know the id of next object.
  def url_after_delete(object)
    return nil unless object

    id = get_next_id(object)
    args = {
      controller: object.show_controller,
      action: object.index_action
    }
    args[:id] = id if id
    url_for(add_query_param(args))
  end

  def get_next_id(object)
    query = passed_query
    return nil unless query
    return nil unless query.model.to_s == object.class.name

    idx = query.index(object)
    return nil unless idx

    query.result_ids[idx + 1] || query.result_ids[idx - 1]
  end

  # Override Rails method of the same name.  Just calls our
  # Textile#textilize_without_paragraph method on the given string.
  def textilize_without_paragraph(str, do_object_links = false)
    Textile.textilize_without_paragraph(str, do_object_links)
  end

  # Override Rails method of the same name.  Just calls our Textile#textilize
  # method on the given string.
  def textilize(str, do_object_links = false)
    Textile.textilize(str, do_object_links)
  end

  # Create stylable file input field with client-side size validation.
  def custom_file_field(obj, attr, opts = {})
    max_size = MO.image_upload_max_size
    max_size_in_mb = (max_size.to_f / 1024 / 1024).round
    file_field = file_field(
      obj,
      attr,
      opts.merge(
        max_upload_msg: :validate_image_file_too_big.l(max: max_size_in_mb),
        max_upload_size: max_size
      )
    )
    content_tag(:span, :select_file.t + file_field, class: "file-field btn") +
      content_tag(:span, :no_file_selected.t)
  end

  def date_select_opts(obj = nil)
    start_year = 20.years.ago.year
    init_value = obj.try(&:when).try(&:year)
    start_year = init_value if init_value && init_value < start_year
    { start_year: start_year,
      end_year: Time.zone.now.year,
      order: [:day, :month, :year] }
  end

  # contents of the <title> in html header
  def title_tag_contents(action_name)
    if @title.present?
      @title.strip_html.html_safe
    elsif TranslationString.where(tag: "title_for_#{action_name}").present?
      :"title_for_#{action_name}".t
    else
      action_name.tr("_", " ").titleize
    end
  end
end
