# frozen_string_literal: true

# added methods relating to js
module JavascriptHelper
  def can_do_ajax?
    modern_browser?(browser) || browser.ie?(8) || Rails.env.test?
  end

  # Use this test to determine if a user can upload multiple images at a time.
  # It checks for support of the following requirements:
  #   Select multiple files button
  #   XHRHttpRequest2
  #   FileAPI
  # CanIuse.com is the source of this information.
  def can_do_multifile_upload?
    modern_browser?(browser) && !browser.ie?(9)
  end

  # from https://github.com/fnando/browser/pull/435 2020-04-13
  def modern_browser?(browser)
    browser.chrome? && browser.version.to_i >= 65 ||
      browser.safari? && browser.version.to_i >= 10 ||
      browser.firefox? && browser.version.to_i >= 52 ||
      browser.ie? && browser.version.to_i >= 11 &&
        !browser.compatibility_view? ||
      browser.edge? && browser.version.to_i >= 15 ||
      browser.opera? && browser.version.to_i >= 50 ||
      browser.facebook? &&
        browser.safari_webapp_mode? &&
        browser.webkit_full_version.to_i >= 602
  end

  # Schedule javascript modules for inclusion in header.  This is much safer
  # than javascript_include_tag(), since that one is ignorant of whether the
  # given module(s) have been included yet or not, and of correct order.
  #   # Example usage in view template:
  #   <% javascript_include "name_lister" %>
  def javascript_include(*args)
    if args.reject { |arg| arg.class == String } != []
      raise(ArgumentError.new(
              "javascript_include doesn't take symbols like :default, etc."
            ))
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
    @javascript_files.unshift("application")
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
