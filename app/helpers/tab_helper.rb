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
#  add_right_tab:: Create new tab set for top-right.
#  new_tab_set::   Create new tab set for top-left.
#  add_tab::       Add tab to last top-left tab set.
#  render_tab::    Render a tab. (used by app/views/layout/application.rhtml)
#  draw_interest_icons:: Draw the three cutesy eye icons.
#
##############################################################################

module ApplicationHelper::Tabs
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
  def new_tab_set(&block)
    @tab_sets ||= []
    @tab_sets.push(new_set = [])
    yield(new_set)
    return new_set
  end

  # Add a tab to an open tab set.  See new_tab_set.
  def add_tab(*args)
    if @tab_sets && @tab_sets.last
      @tab_sets.last.push(args)
    else
      raise(RuntimeError, 'You must place add_tab() calls inside a new_tab_set() block.')
    end
  end

  # Render a tab in HTML.  Used in: app/views/layouts/application.rb
  def render_tab(label, link_args=nil, html_args={})
    if !link_args
      label
    elsif link_args.is_a?(String) && (link_args[0..6] == 'http://')
      "<a href=\"#{link_args}\" target=\"_new\">#{label}</a>"
    elsif html_args.has_key?(:help)
      help = html_args[:help]
      html_args = html_args.dup
      html_args.delete(:help)
      add_context_help(link_to(label, link_args, html_args), help)
    else
      link_to(label, link_args, html_args)
    end
  end

  # Add tab to float off to the right of the main tabs.  There is only one
  # set of these, arranged vertically.
  def add_right_tab(html)
    @right_tabs ||= []
    @right_tabs.push(html)
  end

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
  #     draw_interest_icons(@observation, @interest) if @user
  #   %>
  #
  # This will cause the set of three icons to be rendered floating in the
  # top-right corner of the content portion of the page.
  #
  def draw_interest_icons(object, interest)
    type  = object.class.to_s.underscore.to_sym
    type2 = object.class.to_s
    if !@interest
      alt1 = :interest_watch_help.l(:object => type.l)
      alt2 = :interest_ignore_help.l(:object => type.l)
      img1 = image_tag('watch3.png',  :alt => alt1, :width => '23px', :height => '23px', :class => 'interest_small')
      img2 = image_tag('ignore3.png', :alt => alt2, :width => '23px', :height => '23px', :class => 'interest_small')
      img1 = link_to(img1, :controller => 'interest', :action => 'set_interest', :id => object.id, :type => type2, :state => 1)
      img2 = link_to(img2, :controller => 'interest', :action => 'set_interest', :id => object.id, :type => type2, :state => -1)
      img1 = add_context_help(img1, alt1)
      img2 = add_context_help(img2, alt2)
      add_right_tab("<div>#{img1} #{img2}</div>")
    elsif @interest.state
      alt1 = :interest_watching.l(:object => type.l)
      alt2 = :interest_default_help.l(:object => type.l)
      alt3 = :interest_ignore_help.l(:object => type.l)
      img1 = image_tag('watch2.png',    :alt => alt1, :width => '50px', :height => '50px', :class => 'interest_big')
      img2 = image_tag('halfopen3.png', :alt => alt2, :width => '23px', :height => '23px', :class => 'interest_small')
      img3 = image_tag('ignore3.png',   :alt => alt3, :width => '23px', :height => '23px', :class => 'interest_small')
      img2 = link_to(img2, :controller => 'interest', :action => 'set_interest', :id => object.id, :type => type2, :state => 0)
      img3 = link_to(img3, :controller => 'interest', :action => 'set_interest', :id => object.id, :type => type2, :state => -1)
      img1 = add_context_help(img1, alt1)
      img2 = add_context_help(img2, alt2)
      img3 = add_context_help(img3, alt3)
      add_right_tab("<div>#{img1}<br/>#{img2}#{img3}</div>")
    else
      alt1 = :interest_ignoring.l(:object => type.l)
      alt2 = :interest_watch_help.l(:object => type.l)
      alt3 = :interest_default_help.l(:object => type.l)
      img1 = image_tag('ignore2.png',   :alt => alt1, :width => '50px', :height => '50px', :class => 'interest_big')
      img2 = image_tag('watch3.png',    :alt => alt2, :width => '23px', :height => '23px', :class => 'interest_small')
      img3 = image_tag('halfopen3.png', :alt => alt3, :width => '23px', :height => '23px', :class => 'interest_small')
      img2 = link_to(img2, :controller => 'interest', :action => 'set_interest', :id => object.id, :type => type2, :state => 1)
      img3 = link_to(img3, :controller => 'interest', :action => 'set_interest', :id => object.id, :type => type2, :state => 0)
      img1 = add_context_help(img1, alt1)
      img2 = add_context_help(img2, alt2)
      img3 = add_context_help(img3, alt3)
      add_right_tab("<div>#{img1}<br/>#{img2}#{img3}</div>")
    end
  end
end
