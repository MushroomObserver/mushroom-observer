#
# == Javascript helpers.
#
# This just provides an improved mechanism for including javascripts.
#
#   # In your_view.rhtml:
#   <% javascript_include 'name_lister' %>
#
#   # In header of layout.rhtml:
#   <%= sort_javascript_includes.map {|m| javascript_include_tag(m)} %>
#
# Don't use +javascript_include_tag+ anymore, since it is unsafe.  Note, this
# set of helpers cannot handle the old
# <tt>javascript_include_tag :defaults</tt> functionality yet.
#
# Other helper methods for views:
#   focus_on('id')      Focuses on a form field -- MUST GO INSIDE FORM!
#
################################################################################

module ApplicationHelper

  # This is a list of modules that are sensitive to order.
  JAVASCRIPT_MODULE_ORDER = %w(
    prototype
    effects
    controls
    cached_auto_complete
    window
  )

  # Schedule javascript modules for inclusion in header.  This is much safer
  # than javascript_include_tag(), since that one is ignorant of whether the
  # given module(s) have been included yet or not, and is ignorant of correct
  # order (the prototype modules must be included first in a certain order,
  # followed by our extensions, finally followed by anything else).
  #   # Example usage in view template:
  #   <% javascript_include 'name_lister' %>
  def javascript_include(*args)
    if args.select {|arg| arg.class != String} != []
      raise(ArgumentError, "javascript_include doesn't take symbols like :default, etc.")
    end
    @javascripts = [] if !@javascripts
    @javascripts += args
  end

  # This is called in the header section in the layout.  It returns the
  # javascript modules in correct order (see above).
  #   # Example usage in layout header:
  #   <%= sort_javascript_includes.map {|m| javascript_include_tag(m)} %>
  def sort_javascript_includes
    @javascripts = [] if !@javascripts
    # Stick the ones that care about order first, in their preferred order,
    # ignore duplicates since we'll uniq it later anyway.
    @result = JAVASCRIPT_MODULE_ORDER.select do |m|
      @javascripts.include?(m)
    end + @javascripts
    return @result.uniq
  end

  # Insert a javacsript snippet that causes the browser to focus on a given
  # input field when it loads the page.
  def focus_on(id)
    javascript_tag("document.getElementById('#{id}').focus()")
  end
end
