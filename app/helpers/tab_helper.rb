module ApplicationHelper

  # Create a new set of tabs.  Use like this:
  #   new_tab_set do
  #     add_tab('Bare String')
  #     add_tab('Hard-Coded Link', '/name/show_name/123')
  #     add_tab('External Link', 'http://images.google.com/')
  #     add_tab('Normal Link', :action => :blah, :id => 123, ...)
  #     add_tab('Dangerous Link', { :action => :destroy, :id => 123 }, { :confirm => :are_you_sure.l })
  #   end
  def new_tab_set(&block)
    @tab_sets ||= []
    @tab_sets.push([])
    yield(@tab_sets.last)
    return @tab_sets.last
  end

  # Add a tab to an open tab set.  See new_tab_set.
  def add_tab(*args)
    if @tab_sets && @tab_sets.last
      @tab_sets.last.push(args)
    else
      raise(RuntimeError, 'You must place add_tab() calls inside a new_tab_set() block.')
    end
  end

  # Render a tab in HTML.  (Used in application layout.)
  def render_tab(label, *url_args)
    if url_args.empty?
      label
    elsif url_args[0].is_a?(String) && (url_args[0][0..6] == 'http://')
      "<a href=\"#{url_args[0]}\" target=\"_new\">#{label}</a>"
    else
      link_to(label, *url_args)
    end
  end
end
