# frozen_string_literal: true

#
#  = Integration Session Test Helpers
#
#  Methods in this class are available to integration tests that inherit from
#  MO's IntegrationTestCase (uses rails-dom-testing, not Capybara).
#
#  ==== Sessions
#  login::   Create a session with a given user logged in.
#  login!::  Same thing,but raise an error if it is unsuccessful.
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
#  assert_link_exists::         Check that a link exists somewhere on the page.
#  assert_link_exists_containing::        Check that a link containing a given
#                                         string exists.
#  assert_link_exists_beginning_with::    Check that a link beginning with a
#                                         given string exists.
#  assert_no_link_exists::                Opposite of above.
#  assert_no_link_exists_containing::     Opposite of above.
#  assert_no_link_exists_beginning_with:: Opposite of above.
#
#  ==== Forms
#  open_form::                 Encapsulate filling out and posting a given form.
#  submit_form_with_changes::  Open form, apply Hash of changes, and submit it.
#  assert_form_has_correct_values::  Make sure a given form has been
#                                    initialized correctly.
#
################################################################################

module SessionExtensions
  ##############################################################################
  #
  #  :section: Sessions
  #
  ##############################################################################

  # Login the given user in the current session.
  def login(login = users(:zero_user).login, password = "testpassword",
            remember_me = true)
    login = login.login if login.is_a?(User)
    get("/account/login/new")
    open_form do |form|
      form.change("login", login)
      form.change("password", password)
      form.change("remember_me", remember_me)
      form.submit("Login")
    end
  end

  # Login the given user, testing to make sure it was successful.
  def login!(user, *args)
    login(user, *args)
    assert_flash(/success/i)
    user = User.find_by(login: user) if user.is_a?(String)
    assert_users_equal(user, assigns(:user), "Wrong user ended up logged in!")
  end

  ##############################################################################
  #
  #  :section: Debugging
  #
  ##############################################################################

  # Dump out a list of all the links on the last page rendered.
  def dump_links
    assert_select("a[href]") do |links|
      links.each do |link|
        puts("link: #{link.attributes["href"]}")
      end
    end
  end

  # Save response from last request so you can look at it in a browser.
  def save_page(file = nil)
    file ||= Rails.public_path.join("test.html")
    File.write(file, response.body)
  end

  # Call follow_redirect!, checking for 500 errors and missing language
  # tags.  Saves body of all successful responses for debugging, too.
  def process_with_error_checking(method, url, *args, **kwargs)
    @doing_with_error_checking = true
    Symbol.missing_tags = []
    send(method.downcase.to_s, url, *args, **kwargs)
    follow_redirect! while response.redirect?
    if status == 500
      msg = if (error = controller.instance_variable_get(:@error))
              "#{error}\n#{error.backtrace.join("\n")}"
            else
              "Got unknown 500 error from outside our application?!\n" \
                    "This usually means that a file failed to parse.\n"
            end
      flunk(msg)
    end
    assert_equal([], Symbol.missing_tags,
                 "Language tag(s) are missing. #{url}: #{method}")
    save_page
  ensure
    @doing_with_error_checking = false
  end

  # Override all 'get' calls and do a bunch of extra error checking.
  def get(action, **args)
    if @doing_with_error_checking
      super
    else
      process_with_error_checking("get", action, **args)
    end
  end

  # Override all 'post' calls and do a bunch of extra error checking.
  def post(action, **args)
    if @doing_with_error_checking
      super
    else
      process_with_error_checking("POST", action, **args)
    end
  end

  # Override all 'put' calls and do a bunch of extra error checking.
  def put(action, **args)
    if @doing_with_error_checking
      super
    else
      process_with_error_checking("PUT", action, **args)
    end
  end

  # Override all 'patch' calls and do a bunch of extra error checking.
  def patch(action, **args)
    if @doing_with_error_checking
      super
    else
      process_with_error_checking("PATCH", action, **args)
    end
  end

  # Override all 'delete' calls and do a bunch of extra error checking.
  def delete(action, **args)
    if @doing_with_error_checking
      super
    else
      process_with_error_checking("DELETE", action, **args)
    end
  end

  # Call the original +get+.
  def get_without_redirecting(action, **args)
    @doing_with_error_checking = true
    get(action, **args)
  ensure
    @doing_with_error_checking = false
  end

  # Call the original +post+.
  def post_without_redirecting(action, **args)
    @doing_with_error_checking = true
    post(action, **args)
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
    _path, query = url.split("?")
    params = CGI.parse(query)
    params["q"]
  end

  # Get an Array of URLs for the given links.
  #
  #   # This gets all the name links in the results of the last page.
  #   urls = get_links('div.results a[href^=/names]')
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

  def assert_form_has_correct_values(expected_values, args = [])
    open_form(*args) do |form|
      expected_values.each do |key, value|
        case value
        when true
          form.assert_checked(key)
        when false
          form.assert_checked(key, false)
        else
          form.assert_value(key, value)
        end
      end
    end
  end

  def submit_form_with_changes(changes, button = nil, args = [])
    open_form(*args) do |form|
      changes.each do |key, value|
        case value
        when true
          form.check(key)
        when false
          form.uncheck(key)
        else
          form.change(key, value)
        end
      end
      form.submit(button)
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
      if action.end_with?("/new", "/edit")
        action = if action.end_with?("/new")
                   action.delete_suffix("/new")
                 elsif action.end_with?("/edit")
                   action.delete_suffix("/edit")
                 end
      end
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
      raise("Missing page called #{name.inspect}!") if @page_stack.empty?
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
  # Sample use:
  #   click_mo_link(label: "Show Observation")
  #   click_mo_link(href: /names/)
  #   click_mo_link(label: "User", in: :sort_tabs)
  def click_mo_link(args = {})
    return true if try_finding_matching_anchor(args)
    return true if try_finding_matching_button(args)

    assert(false, "Expected a link matching: #{args.inspect}")
  end

  def try_finding_matching_anchor(args)
    extra_args = []
    select = anchor_url_select_spec(args[:href], extra_args)
    select = "#{section_select_spec(args[:in])} #{select}" if args[:in]
    assert_select(select, *extra_args) do |links|
      links.each do |link|
        next unless match_link_by_label(link, args[:label])

        url = CGI.unescapeHTML(link.attributes["href"])
        get(url)
        return true
      end
    end
    false
  end

  def try_finding_matching_button(args)
    extra_args = []
    select = button_url_select_spec(args[:href], extra_args)
    select = "#{section_select_spec(args[:in])} #{select}" if args[:in]
    assert_select(select, *extra_args) do |forms|
      forms.each do |form|
        form.css("input[type=submit]").each do |button|
          next unless match_link_by_label(button, args[:label])

          url = CGI.unescapeHTML(form.attributes["action"])
          params = button_link_form_values(form, button)
          post(url, params: params)
          return true
        end
      end
    end
    false
  end

  # Filter anchor links based on URL.
  def anchor_url_select_spec(*args)
    url_select_spec("a", "href", *args)
  end

  # Filter button links based on URL.
  def button_url_select_spec(*args)
    url_select_spec("form", "action", *args)
  end

  def url_select_spec(elem, attr, arg, select_args)
    case arg
    when Regexp
      select_args << arg
      "#{elem}:match('#{attr}',?)"
    when String
      "#{elem}[#{attr}^='#{arg}']"
    else
      "#{elem}[#{attr}]"
    end
  end

  # Restrict search to a certain section on the page.
  def section_select_spec(arg)
    case arg
    when :left_tabs
      "#left_tabs"
    when :right_tabs
      "#right_tabs"
    when :sort_tabs
      "#sorts"
    when :left_panel
      "#navigation"
    when :results
      "#results"
    when :title
      "#title_bar"
    else
      arg
    end
  end

  # Filter based on button label.
  def match_link_by_label(elem, arg)
    case arg
    when :image
      /img /.match?(elem.to_s)
    when Regexp
      arg.match?(elem.to_s)
    when String
      elem.to_s.index(arg)
    else
      true
    end
  end

  def button_link_form_values(form, button)
    params = {}
    form.css("input").each do |input|
      next unless input.attributes["type"].to_s == "hidden"

      name = CGI.unescapeHTML(input.attributes["name"])
      val  = CGI.unescapeHTML(input.attributes["value"])
      params[name] = val
    end
    params["submit"] = CGI.unescapeHTML(button.attributes["value"])
    params
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
    assert_select("a[href#{mod}='#{url}']", { minimum: 1 },
                  "Expected to find link to #{url}")
  end

  def assert_no_link_exists_general_case(url, mod)
    assert_select("a[href#{mod}='#{url}']", { count: 0 },
                  "Shouldn't be any links to #{url}")
  end
end
