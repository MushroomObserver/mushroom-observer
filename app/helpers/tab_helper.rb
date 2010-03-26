#
#  = Tab Helpers
#
#  This is a set of helpers to standardize the creation of the tab-links
#  found in the top-left of the content of each page.  See new_tab_set for
#  more documentation on usage from your views.
#
#  Internally, tab sets are stored in the "global" +@tab_sets+ -- an Array of
#  tab sets, each of which is an Array of sets of arguments for link_to.
#  They are rendered inside app/views/layouts/application.rb.
#
#  *NOTE*: These are all included in ApplicationHelper.
#
#  == Methods
#
#  draw_prev_next_tabs::  Create tab set for prev/index/next links.
#  new_tab_set::          Create new tab set for top-left.
#  custom_tab_set::       Add custom-made tab set.
#  add_tab::              Add tab to last top-left tab set.
#  add_tabs::             Add zero or more tabs to last top-left tab set.
#  render_tab::           Render a tab. (used by app/views/layout/application.rhtml)
#
#  add_right_tab::        Create new tab set for top-right.
#  draw_interest_icons::  Draw the three cutesy eye icons.
#
##############################################################################

module ApplicationHelper::Tabs

  # Render a set of tabs for the prev/index/next links.
  def draw_prev_next_tabs(object, mappable=false)
    type = object.class.name.underscore
    new_tab_set do
      args = {
        :controller => object.show_controller,
        :id         => object.id,
        :params     => query_params,
      }
      add_tab("« #{:PREV.t}",  args.merge(:action => "prev_#{type}" ))
      add_tab(:INDEX.t, args.merge(:action => "index_#{type}"))
      if mappable
        add_tab(:MAP.t,
          :controller => 'location',
          :action => 'map_locations',
          :params => query_params
        )
      end
      add_tab("#{:NEXT.t} »",  args.merge(:action => "next_#{type}"  ))
    end
  end

  # Create a new set of tabs.  Use like this:
  #
  #   new_tab_set do
  #     add_tab('Bare String')
  #     add_tab('Hard-Coded Link', '/name/show_name/123')
  #     add_tab('External Link', 'http://images.google.com/')
  #     add_tab('Normal Link', :action => :blah, :id => 123, ...)
  #     add_tab('Dangerous Link', { :action => :destroy, :id => 123 },
  #                               { :confirm => :are_you_sure.l })
  #   end
  #
  # Tab sets now support headers.  Syntaxes allowed are:
  #
  #   new_tab_set
  #   new_tab_set("Header:")
  #   new_tab_set("Header:", [tab1, tab2, ...])
  #   new_tab_set([tab1, tab2, ...]) # (no header)
  #
  # These render like:
  #
  #   Header: link1 | link2 | link3 | ...
  #
  def new_tab_set(header=nil, tabs=nil, &block)
    header, tabs = nil, header if header.is_a?(Array)
    if tabs && tabs.empty?
      new_set = nil
    else
      @tab_sets ||= []
      @tab_sets.push(new_set = [header])
      add_tabs(tabs) if tabs
      yield(new_set) if block
    end
    return new_set
  end

  # Add custom-made tab set.
  def custom_tab_set(set)
    @tab_sets ||= []
    @tab_sets.push(set)
  end

  # Change the header of the open tab set.
  def set_tab_set_header(header)
    if @tab_sets and @tab_sets.last
      @tab_sets.last.first = header
    else
      raise(RuntimeError, 'You forgot to call new_tab_set().')
    end
  end

  # Add zero or more tabs to an open tab set.  See +new_tab_set+.
  def add_tabs(tabs)
    if tabs.is_a?(Array)
      for tab in tabs
        add_tab(*tab)
      end
    end
  end

  # Add a tab to an open tab set.  See +new_tab_set+.
  def add_tab(*args)
    if @tab_sets and @tab_sets.last
      @tab_sets.last.push(args)
    else
      raise(RuntimeError, 'You must place add_tab() calls inside a new_tab_set() block.')
    end
  end

  # Render tab sets in upper left of page body.  (Only used by app layout.)
  def render_tab_sets
    if @tab_sets
      content_tag(:div, :class => 'tab_sets') do
        @tab_sets.map do |set|
          if set.is_a?(Array)
            render_tab_set(*set)
          else
            set.to_s
          end
        end.join('')
      end
    end
  end

  # Render one tab set in upper left of page body.  (Only used by
  # +render_tab_sets+.)
  def render_tab_set(header, *links)
    header += ' ' if header
    content_tag(:div, :class => 'tab_set') do
      header.to_s + links.map do |tab|
        render_tab(*tab)
      end.join(' | ') + '<br/>'
    end
  end

  # Render a tab in HTML.  Used in: app/views/layouts/application.rb
  def render_tab(label, link_args=nil, html_args={})
    if !link_args
      result = label
    elsif link_args.is_a?(String) && (link_args[0..6] == 'http://')
      result = "<a href=\"#{link_args}\" target=\"_new\">#{label}</a>"
    else
      if link_args.is_a?(Hash) && link_args.has_key?(:help)
        help = link_args[:help]
        link_args = link_args.dup
        link_args.delete(:help)
      elsif html_args.has_key?(:help)
        help = html_args[:help]
        html_args = html_args.dup
        html_args.delete(:help)
      else
        help = nil
      end
      link = link_to(label, link_args, html_args)
      link = add_context_help(link, help) if help
      result = link
    end
    return result
  end

  ##############################################################################
  #
  #  :section: Right Tabs
  #
  ##############################################################################

  # Draw the cutesy eye icons in the upper right side of screen.  It does it
  # by creating a "right" tab set.  Thus this must be called in the header of
  # the view and must not actually be rendered.  Typical usage would be:
  #
  #   # At top of view:
  #   <%
  #     # Specify the page's title.
  #     @title = "Page Title"
  #
  #     # Define set of linked text tabs for top-left.
  #     new_tab_set do
  #       add_tab("Tab Label One", :link => args, ...)
  #       add_tab("Tab Label Two", :link => args, ...)
  #       ...
  #     end
  #
  #     # Draw interest icons in the top-right.
  #     draw_interest_icons(@object)
  #   %>
  #
  # This will cause the set of three icons to be rendered floating in the
  # top-right corner of the content portion of the page.
  #
  def draw_interest_icons(object)
    if @user
      type = object.class.name.underscore.to_sym

      # Create link to change interest state.
      def interest_link(label, object, state) #:nodoc:
        link_to(label,
          :controller => 'interest',
          :action => 'set_interest',
          :id => object.id,
          :type => object.class.name,
          :state => state,
          :params => query_params
        )
      end

      # Create large icon image.
      def interest_icon_big(type, alt) #:nodoc:
        image_tag("#{type}2.png",
          :alt => alt,
          :width => '50px',
          :height => '50px',
          :class => 'interest_big'
        )
      end

      # Create small icon image.
      def interest_icon_small(type, alt) #:nodoc:
        image_tag("#{type}3.png",
          :alt => alt,
          :width => '23px',
          :height => '23px',
          :class => 'interest_small'
        )
      end

      case @user.interest_in(object)
      when :watching
        alt1 = :interest_watching.l(:object => type.l)
        alt2 = :interest_default_help.l(:object => type.l)
        alt3 = :interest_ignore_help.l(:object => type.l)
        img1 = interest_icon_big('watch', alt1)
        img2 = interest_icon_small('halfopen', alt2)
        img3 = interest_icon_small('ignore', alt3)
        img2 = interest_link(img2, object, 0)
        img3 = interest_link(img3, object, -1)
        img1 = add_context_help(img1, alt1)
        img2 = add_context_help(img2, alt2)
        img3 = add_context_help(img3, alt3)
        add_right_tab("<div>#{img1}<br/>#{img2}#{img3}</div>")

      when :ignoring
        alt1 = :interest_ignoring.l(:object => type.l)
        alt2 = :interest_watch_help.l(:object => type.l)
        alt3 = :interest_default_help.l(:object => type.l)
        img1 = interest_icon_big('ignore', alt1)
        img2 = interest_icon_small('watch', alt2)
        img3 = interest_icon_small('halfopen', alt3)
        img2 = interest_link(img2, object, 1)
        img3 = interest_link(img3, object, 0)
        img1 = add_context_help(img1, alt1)
        img2 = add_context_help(img2, alt2)
        img3 = add_context_help(img3, alt3)
        add_right_tab("<div>#{img1}<br/>#{img2}#{img3}</div>")

      else
        alt1 = :interest_watch_help.l(:object => type.l)
        alt2 = :interest_ignore_help.l(:object => type.l)
        img1 = interest_icon_small('watch', alt1)
        img2 = interest_icon_small('ignore', alt2)
        img1 = interest_link(img1, object, 1)
        img2 = interest_link(img2, object, -1)
        img1 = add_context_help(img1, alt1)
        img2 = add_context_help(img2, alt2)
        add_right_tab("<div>#{img1} #{img2}</div>")
      end
    end
  end

  # Add tab to float off to the right of the main tabs.  There is only one
  # set of these, arranged vertically.
  def add_right_tab(html)
    @right_tabs ||= []
    @right_tabs.push(html)
  end
end
