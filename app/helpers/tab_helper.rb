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
      help = help_args[:help]
      html_args = html_args.dup.delete(:help)
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
end
