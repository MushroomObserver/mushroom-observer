#
#  = Integration Session Test Helpers
#
#  Methods in this class are available to all the integration tests.
#
#  ==== Debugging
#  dump_links::       Show list of all the links on the last page rendered.
#  save_page::        Save response from last request in a file.
#  get::              Call follow_redirect! with extra error checking.
#  post::             Call follow_redirect! with extra error checking.
#  get_without_redirecting::  Call the original 'get'.
#  post_without_redirecting:: Call the original 'post'.
#
#  ==== Helpers
#  parse_query_params:: Get (our) query params from the given URL.
#  get_links::        Get an Array of URLs for a set of links.
#
#  ==== Navigation
#  push_page::        Save response from last query so we can go back to it.
#  go_back::          Go back a number of times.
#  click::            Click on first link that matches the given args.
#
#  ==== Links
#  assert_link_exists::                   Check that a link exists somewhere on the page.
#  assert_link_exists_containing::        Check that a link containing a given string exists.
#  assert_link_exists_beginning_with::    Check that a link beginning with a given string exists.
#  assert_no_link_exists::                Opposite of above.
#  assert_no_link_exists_containing::     Opposite of above.
#  assert_no_link_exists_beginning_with:: Opposite of above.
#
#  ==== Forms
#  open_form::        Encapsulate filling out and posting a given form.
#  submit_form_with_changes::  Open form, apply Hash of changes, and submit it.
#  assert_form_has_correct_values::  Make sure a given form has been initialized correctly.
#
################################################################################

module SessionExtensions
  ##############################################################################
  #
  #  :section: Debugging
  #
  ##############################################################################

  # Dump out a list of all the links on the last page rendered.
  def dump_links
    assert_select("a[href]") do |links|
      for link in links
        puts "link: #{link.attributes["href"]}"
      end
    end
  end

  # Save response from last request so you can look at it in a browser.
  def save_page(file = nil)
    file ||= "#{::Rails.root}/public/test.html"
    File.open(file, "w") do |fh|
      fh.write(response.body)
    end
  end

  # Call follow_redirect!, checking for 500 errors and missing language
  # tags.  Saves body of all successful responses for debugging, too.
  def process_with_error_checking(method, url, *args)
    @doing_with_error_checking = true
    Symbol.missing_tags = []
    send(method.downcase.to_s, url, *args)
    follow_redirect! while response.redirect?
    if status == 500
      if error = controller.instance_variable_get("@error")
        msg = "#{error}\n#{error.backtrace.join("\n")}"
      else
        msg = "Got unknown 500 error from outside our application?!\n" \
              "This usually means that a file failed to parse.\n"
      end
      flunk msg
    end
    assert_equal([], Symbol.missing_tags, "Language tag(s) are missing. #{url}: #{method}")
    save_page
  ensure
    @doing_with_error_checking = false
  end

  # Override all 'get' calls and do a bunch of extra error checking.
  def get(*args)
    if !@doing_with_error_checking
      process_with_error_checking("get", *args)
    else
      super
    end
  end

  # Override all 'post' calls and do a bunch of extra error checking.
  def post(*args)
    if !@doing_with_error_checking
      process_with_error_checking("POST", *args)
    else
      super
    end
  end

  # Call the original +get+.
  def get_without_redirecting(*args)
    @doing_with_error_checking = true
    get(*args)
  ensure
    @doing_with_error_checking = false
  end

  # Call the original +post+.
  def post_without_redirecting(*args)
    @doing_with_error_checking = true
    post(*args)
  ensure
    @doing_with_error_checking = false
  end

  ##############################################################################
  #
  #  :section: Random Helpers
  #
  ##############################################################################

  # Get string representing (our) query from the given URL.  Defaults to the
  # current page's URL.  (In practice, for now, this is just the Query id.)
  def parse_query_params(url = path)
    path, query = url.split("?")
    params = CGI.parse(query)
    params["q"]
  end

  # Get an Array of URLs for the given links.
  #
  #   # This gets all the name links in the results of the last page.
  #   urls = get_links('div.results a[href^=/name/show_name]')
  #
  def get_links(*args)
    results = []
    assert_select(*args) do |links|
      results = links.map { |l| l.attributes["href"] }
    end
    results
  end

  ##############################################################################
  #
  #  :section: Form Helpers
  #
  ##############################################################################

  def assert_form_has_correct_values(expected_values)
    open_form do |form|
      for key, value in expected_values
        if value == true
          form.assert_checked(key)
        elsif value == false
          form.assert_checked(key, false)
        else
          form.assert_value(key, value)
        end
      end
    end
  end

  def submit_form_with_changes(changes)
    open_form do |form|
      changes.each do |key, value|
        if value == true
          form.check(key)
        elsif value == false
          form.uncheck(key)
        else
          form.change(key, value)
        end
      end
      form.submit
    end
  end

  # Look up a given form, initialize a Hash of parameters for it, and wrap up
  # the whole thing in a Form instance.  Returns (and yields) an instance of
  # IntegrationSession::Form.  (If no parameters passed, by default it looks
  # for a form that posts back to the same page.)
  def open_form(*args)
    form = nil
    if args == []
      action = path.sub(/\?.*/, "")
      args << "form[action^='#{action}']"
    end
    assert_select(*args) do |elems|
      assert_equal(1, elems.length,
                   "Found multiple forms matching #{args.inspect}.")
      elem = elems.first
      assert_equal("form", elem.name,
                   "Expected #{args.inspect} to find a form!")
      form = Form.new(self, elem)
      yield(form) if block_given?
    end
    form
  end

  ##############################################################################
  #
  #  :section: Navigation
  #
  ##############################################################################

  # Save response from last query on the page stack.
  def push_page(name = "")
    @page_stack ||= []
    @page_stack.push(name: name, path: path, body: response.body)
  end

  # Go back one or more times and restore a previous query result.  If called
  # with no argument, it just restores the previous page and doesn't affect the
  # stack.  If called with 2, it pops one page off the stack then restores the
  # page before that.  And so on.
  def go_back(arg = 1)
    if arg.is_a?(Integer)
      while arg > 1
        @page_stack.pop
        arg -= 1
      end
    else
      @page_stack.pop while @page_stack.any? && (@page_stack.last[:name] != arg)
      fail("Missing page called #{name.inspect}!") if @page_stack.empty?
    end
    response.body = @page_stack.last[:body]
    request.env["PATH_INFO"] = @page_stack.last[:path]
    @html_document = nil # cause rails to reparse document
    save_page
  end

  # Click on the first link matching the given args.  Args can be:
  # label:: Label contains a String or matches a Regexp.
  # href::  URL starts with a String or matches a Regexp.
  # in::    Link contained in a given element type(s).
  def click(args = {})
    select = "a[href]"
    sargs  = []

    # Filter links based on URL.
    if arg = args[:href]
      if arg.is_a?(Regexp)
        select = "a:match('href',?)"
        sargs << arg
      else
        select = "a[href^='#{arg}']"
      end
    end

    # Filter links by parent element types.
    if arg = args[:in]
      if arg == :left_tabs
        arg = 'div#left_tabs'
      elsif arg == :right_tabs
        arg = 'div#right_tabs'
      elsif arg == :sort_tabs
        arg = 'div#sorts'
      elsif arg == :left_panel
        arg = 'div#navigation'
      elsif arg == :results
        arg = "div.results"
      elsif arg == :title
        arg = 'div#title'
      end
      select = "#{arg} #{select}"
    end

    done = false
    assert_select(select, *sargs) do |links|
      for link in links
        match = true

        # Filter based on link "label" (can be an image too, for example).
        if arg = args[:label]
          if arg == :image
            match = false unless /img /.match?(link.to_s)
          elsif arg.is_a?(Regexp)
            match = false unless arg.match?(link.to_s)
          else
            match = false unless link.to_s.index(arg)
          end
        end

        # Click on first link that matches everything.
        if match
          url = CGI.unescapeHTML(link.attributes["href"])
          get(url)
          done = true
          break
        end
      end
    end

    assert done, "Expected a link matching: #{args.inspect}"
  end

  ##############################################################################
  #
  #  :section: assert_select Wrappers
  #
  ##############################################################################

  def assert_link_exists(url)
    assert_link_exists_general_case(url, "")
  end

  def assert_no_link_exists(url)
    assert_no_link_exists_general_case(url, "")
  end

  def assert_link_exists_containing(url)
    assert_link_exists_general_case(url, "*")
  end

  def assert_no_link_exists_containing(url)
    assert_no_link_exists_general_case(url, "*")
  end

  def assert_link_exists_beginning_with(url)
    assert_link_exists_general_case(url, "^")
  end

  def assert_no_link_exists_beginning_with(url)
    assert_no_link_exists_general_case(url, "^")
  end

  def assert_link_exists_general_case(url, mod)
    assert_select("a[href#{mod}='#{url}']", { minimum: 1 }, "Expected to find link to #{url}")
  end

  def assert_no_link_exists_general_case(url, mod)
    assert_select("a[href#{mod}='#{url}']", { count: 0 }, "Shouldn't be any links to #{url}")
  end
end
