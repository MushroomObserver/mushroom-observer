module JavascriptHelper
  # For now, just use Browser gem's "modern?" criteria.
  # (Webkit, Firefox 17+, IE 9+ and Opera 12+)
  def can_do_ajax?
    browser.modern? || browser.ie?(8) || Rails.env == "test"
  end

  # Use this test to determine if a user can upload multiple images at a time.
  # It checks for support of the following requirements:
  #   Select multiple files button
  #   XHRHttpRequest2
  #   FileAPI
  # CanIuse.com is the source of this information.
  def can_do_multifile_upload?
    browser.modern? && !browser.ie?(9)
  end

  # Schedule javascript modules for inclusion in header.  This is much safer
  # than javascript_include_tag(), since that one is ignorant of whether the
  # given module(s) have been included yet or not, and of correct order.
  #   # Example usage in view template:
  #   <% javascript_include "name_lister" %>
  def javascript_include(*args)
    if args.select { |arg| arg.class != String } != []
      fail(ArgumentError, "javascript_include doesn't take symbols like :default, etc.")
    end

    @javascript_files ||= []
    @javascript_files += args
  end

  # This is called in the header section in the layout.  It returns the
  # javascript modules in correct order (see above).
  #   # Example usage in layout header:
  #   <%= sort_javascript_includes.map {|m| javascript_include_tag(m)} %>
  def javascript_includes
    @javascript_files ||= []
    @javascript_files.unshift "application"
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
