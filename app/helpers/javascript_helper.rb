# frozen_string_literal: true

# added methods relating to js
module JavascriptHelper
  # Schedule javascript modules for inclusion in footer.  This is much safer
  # than javascript_include_tag(), since that one is ignorant of whether the
  # given module(s) have been included yet or not, and of correct order.
  #   # Example usage in view template:
  #   <% javascript_include "name_lister" %>
  def javascript_include(*args)
    if args.reject { |arg| arg.instance_of?(String) } != []
      raise(
        ArgumentError.new(
          "javascript_include doesn't take symbols like :default, etc."
        )
      )
    end

    @javascript_files ||= []
    @javascript_files += args
  end

  # This is called in the footer section in the layout.  It returns the
  # javascript modules in correct order (see above).
  #   # Example usage in layout footer:
  #   <%= sort_javascript_includes.map {|m| javascript_include_tag(m)} %>
  def javascript_includes
    @javascript_files ||= []
    @javascript_files.unshift("mo_application")
    @javascript_files.uniq
  end

  # Register a bit of javascript to inject after includes at bottom of page.
  #   <% inject_javascript_at_end %(
  #     this_javascript_will_run_at_end();
  #   ) %>
  # Important:  Do not use "//" comment lines as they will block code execution
  #            #when script is minified
  def inject_javascript_at_end(*args)
    @javascript_codes ||= []
    @javascript_codes += args
  end

  # Return javascript snippets scheduled for inclusion at the end of the page.
  def injected_javascripts
    @javascript_codes || []
  end
end
