# frozen_string_literal: true
#
#  = Controller Test Helpers
#
#  Methods in this class are available to all the functional tests.
#
#  == Request helpers
#  reget::                      Resets request and calls +get+.
#  login::                      Login a user.
#  logout::                     Logout current user.
#  make_admin::                 Make current user an admin & turn on admin mode.
#  get_with_dump::              Send GET, no login required.
#  requires_login::             Send GET, login required.
#  requires_user::              Send GET, certain user must be logged in.
#  post_with_dump::             Send POST, no login required.
#  post_requires_login::        Send POST, login required.
#  post_requires_user::         Send POST, certain user must be logged in.
#  html_dump::                  Dump response body to file for W3C validation.
#  save_response::              Dump response body to public/test.html
#                               for debugging.
#  get_without_clearing_flash::  Wrapper: calls +get+
#                                without clearing flash errors.
#  post_without_clearing_flash:: Wrapper: calls +post+
#                                without clearing flash errors.
#
#  == HTML Helpers
#  url_for::                    Get URL for +link_to+ style Hash of args.
#  extract_links::              Get Array of show_object links on page.
#  extract_error_from_body::    Extract error and stacktrace
#                               from 500 response body.
#
#  == HTML Assertions
#  assert_link_in_html::        A given link exists.
#  assert_image_link_in_html::  A given link with an image
#                               instead of text exists#
#  assert_form_action::         A form posting to a given action exists.
#  assert_response_equal_file:: Response body is same as copy in a file.
#  assert_request::             Check heuristics of an arbitrary request.
#  assert_response::            Check that last request resulted in a
#                               given redirect.
#  assert_action_partials::     Check that each of the given partials were
#                               rendered(?)
#  assert_redirect_match::      Check that last request resulted in a given
#                               redirect(?)
#  assert_input_value::         Check default value of a form field.
#  assert_checkbox_state::      Check state of checkbox.
#  assert_textarea_value::      Check value of textarea.
#
################################################################################

module ControllerExtensions
  ##############################################################################
  #
  #  :section: Request helpers
  #
  ##############################################################################

  # Second "get" won't update fullpath, so we must reset the request.
  def reget(*args)
    @request = @request.class.new
    get(*args)
  end

  # Call +get+ without clearing the flash (which we do by default).
  def get_without_clearing_flash(*args)
    @without_clearing_flash = true
    get(*args)
  end

  # Call +post+ without clearing the flash (which we do by default).
  def post_without_clearing_flash(*args)
    @without_clearing_flash = true
    post(*args)
  end

  # Log a user in (affects session only).
  def login(user = "rolf", password = "testpassword")
    user = User.authenticate(user, password)
    assert(user, "Failed to authenticate user <#{user}> " \
                 "with password <#{password}>.")
    @request.session[:user_id] = user.id
    User.current = user
  end

  # Log a user out (affects session only).
  def logout
    @request.session[:user_id] = nil
    @request.session[:admin] = nil
    User.current = nil
  end

  # Make the logged-in user admin and turn on admin mode.
  def make_admin(user = "rolf", password = "testpassword")
    user = login(user, password)
    @request.session[:admin] = true
    unless user.admin
      user.admin = 1
      user.save
    end
    user
  end

  # Send a GET request, and save the result in a file for w3c validation.
  #
  #   # Send request, but ignore response.
  #   get(:action, params)
  #
  #   # Send request, and save response in ../html/action_0.html.
  #   get_with_dump(:action, params)
  #
  def get_with_dump(page, params = {})
    get(page, params: params)
    html_dump(page, @response.body, params)
  end

  # Send a POST request, and save the result in a file for w3c validation.
  #
  #   # Send request, but ignore response.
  #   post(:action, params)
  #
  #   # Send request, and save response in ../html/action_0.html.
  #   post_with_dump(:action, params)
  #
  def post_with_dump(page, params = {})
    post(page, params: params)
    html_dump(page, @response.body, params)
  end

  # Send GET request to a page that should require login.
  #
  #   # Make sure only logged-in users get to see this page.
  #   requires_login(:edit_name, id: 1)
  #
  def requires_login(page, *args)
    either_requires_either(:get, page, nil, *args)
  end

  # Send POST request to a page that should require login.
  #
  #   # Make sure only logged-in users get to post this page.
  #   post_requires_login(:edit_name, id: 1)
  #
  def post_requires_login(page, *args)
    either_requires_either(:post, page, nil, *args)
  end

  # Send GET request to a page that should require a specific user.
  #
  #   # Make sure only reviewers can see this page (non-reviewers get
  #   # redirected to "show_location").
  #   requires_user(:review_authors, :show_location, id: 1)
  #   requires_user(:review_authors, [:location, :show_location], id: 1)
  #
  def requires_user(*args)
    either_requires_either(:get, *args)
  end

  # Send POST request to a page that should require login.
  #
  #   # Make sure only owner can edit observation (non-owners get
  #   # redirected to "show_observation").
  #   post_requires_user(:edit_obs, :show_obs, notes: 'new notes')
  #   post_requires_user(:edit_obs, [:observer, :show_obs],
  #                      notes: 'new notes')
  #
  def post_requires_user(*args)
    either_requires_either(:post, *args)
  end

  # Helper used by the blah_requires_blah methods.
  # method::        [Request method: "GET" or "POST".
  #                 - Supplied automatically by all four "public" methods.]
  # page::          Name of action.
  # altpage::       [Name of page redirected to if user wrong.
  #                 - Only include in +requires_user+ and +post_requires_user+.]
  # params::        Hash of parameters for action.
  # stay_on_page::  Does it render template of same name as action if succeeds?
  # username::      Which user should be logged in (default is "rolf").
  # password::      Which password should it try to use
  #                 (default is "testpassword").
  #
  #   # Make sure only logged-in users get to see this page, and that it
  #   # renders the template of the same name when it succeeds.
  #   requires_login(:edit_name, id: 1)
  #
  #   # Make sure only logged-in users get to post this page, but that it
  #   # renders the template of a different name (or redirects) on success.
  #   post_requires_login(:edit_name, id: 1, false)
  #
  #   # Make sure only reviewers can see this page (non-reviewers get
  #   # redirected to "show_location"), and that it renders
  #   # the template of the same name when it succeeds.
  #   requires_user(:review_authors, {id: 1}, :show_location)
  #
  #   # Make sure only owner can edit observation (non-owners get
  #   # redirected to "show_observation"), and that it redirects to
  #   # "show_observation" when it succeeds (last argument).
  #   post_requires_user(:edit_observation, {notes: 'new notes'},
  #     :show_observation, [:show_observation])
  #
  #   # Even more general case where second case renders a template:
  #   post_requires_user(:action, params,
  #     {controller: controller1, action: :access_denied, ...},
  #     :success_template)
  #
  #   # Even more general case where both cases redirect:
  #   post_requires_user(:action, params,
  #     {controller: controller1, action: :access_denied, ...},
  #     {controller: controller2, action: :succeeded, ...})
  #
  def either_requires_either(method, page, altpage, params = {},
                             username = "rolf", password = "testpassword")
    assert_request(
      method: method,
      action: page,
      params: params,
      user: (params[:username] || username),
      password: (params[:password] || password),
      require_login: :login,
      require_user: altpage ? [altpage].flatten : nil
    )
  end

  # The whole purpose of this is to create a directory full of sample HTML
  # files that we can run the W3C validator on -- this has nothing to do with
  # debugging!  This happens automatically if following directory exists:
  #
  #   ::Rails.root.to_s/../html
  #
  # Files are created:
  #
  #   show_user_0.html
  #   show_user_1.html
  #   show_user_2.html
  #   etc.
  #
  def html_dump(label, html, _params)
    html_dir = "../html"
    return unless File.directory?(html_dir) && html[0..11] != "<html><body>"

    file_name = "#{html_dir}/#{label}.html"
    count = 0
    while File.exist?(file_name)
      file_name = "#{html_dir}/#{label}_#{count}.html"
      count += 1
      if count > 100
        raise(RangeError,
              "More than 100 files found with a label of '#{label}'")
      end
    end
    print "Creating html_dump file: #{file_name}\n"
    file = File.new(file_name, "w")
    # show_params(file, params, "params")
    file.write(html)
    file.close
  end

  # Add the hash of parameters to the dump file for diagnostics.
  def show_params(file, hash, prefix)
    if hash.is_a?(Hash)
      hash.each { |k, v| show_params(file, v, "#{prefix}[#{k}]") }
    else
      file.write("#{prefix} = [#{hash}]<br>\n")
    end
  end

  # This writes @response.body to the given file
  # (relative to <tt>::Rails.root.to_s</tt>).
  def save_response(file = "public/test.html")
    File.open("#{::Rails.root}/#{file}", "w:utf-8") do |fh|
      fh.write(@response.body)
    end
  end

  ##############################################################################
  #
  #  :section: HTML Helpers
  #
  ##############################################################################

  # Return URL for +link_to+ style Hash of parameters.
  def url_for(args = {})
    # By default expect relative links.  Allow caller to override by
    # explicitly setting only_path: false.
    args[:only_path] = true unless args.key?(:only_path)
    URI.decode_www_form_component(@controller.url_for(args))
  end

  # Extract error message and backtrace from Rails's 500 response.  This should
  # be obsolete now that all the test controllers re-raise exceptions.  But
  # just in case, here it is...
  def extract_error_from_body
    str = @response.body
    str.gsub!(/<pre>.*?<.pre>/m) { |x| x.gsub(/\s*\n/, "<br>") }
    str.sub!(/^.*?<p>/m, "")
    str.sub!(/<.div>.*/m, "")
    str.sub!(/<div.*<div.*?>/m, "")
    str.sub!(/<p><code>RAILS.*?<.p>/, "")
    str.gsub!(/<p><.p>/m, "")
    str.gsub!(/\s+/m, " ")
    str.gsub!("<br>", "\n")
    str.gsub!("</p>", "\n\n")
    str.gsub!(": <pre>", "\n")
    str.gsub!(/<.*?>/, "")
    str.gsub!(/^ */, "")
    str.gsub!(/\n\n+/, "\n\n")
    str.sub!(/\A\s*/, "\n")
    str.sub!(/\s*\Z/, "\n")
  end

  ##############################################################################
  #
  #  :section: HTML assertions
  #
  ##############################################################################

  def raise_params(opts)
    if opts.member?(:params)
      result = opts.clone
      result.delete(:params)
      result.merge(opts[:params])
    else
      opts
    end
  end

  # Assert the existence of a given link in the response body, and check
  # that it points to the right place.
  def assert_link_in_html(label, url_opts, _msg = nil)
    revised_opts = raise_params(url_opts)
    url = url_for(revised_opts)
    assert_select("a[href='#{url}']", text: label)
  end

  def assert_image_link_in_html(img_src, url_opts, _msg = nil)
    revised_opts = raise_params(url_opts)
    url = url_for(revised_opts)
    assert_select("a[href = '#{url}']>img") do
      assert_select(":match('src', ?)", img_src)
    end
  end

  # Assert that a form exists which posts to the given url.
  def assert_form_action(url_opts, msg = nil)
    url_opts[:only_path] = true if url_opts[:only_path].nil?
    url = @controller.url_for(url_opts)
    url.force_encoding("UTF-8") if url.respond_to?(:force_encoding)
    url = URI.decode_www_form_component(url)
    # Find each occurrance of <form action="blah" method="post">.
    found_it = false
    found = {}
    @response.body.split(/<form [^<>]*action/).each do |str|
      next unless str =~ /^="([^"]*)" [^>]*method="post"/

      url2 = URI.decode_www_form_component(Regexp.last_match(1)).gsub("&amp;",
                                                                      "&")
      if url == url2
        found_it = true
        break
      end
      found[url2] = 1
    end
    return pass if found_it

    if found.keys
      flunk(build_message(
              msg, "Expected HTML to contain form that posts to <#{url}>," \
                  "but only found these: <#{found.keys.sort.join(">, <")}>."
            ))
    else
      flunk(build_message(
              msg, "Expected HTML to contain form that posts to <#{url}>," \
              "but found nothing at all."
            ))
    end
  end

  # Assert that a response body is same as contents of a given file.
  #   get(:action, params)
  #   assert_response_equal_file("#{path}/file")
  #
  # Assert that a response body is same as contents of a given file,
  # where file has given encoding. This is a work-around for a Net::HTTP issue
  # that causes response-body encoding to be set incorrectly.
  #   get(:action, params)
  #   assert_response_equal_file(["#{path}/file", "ISO-8859-1"])
  #
  # Pass in a block to use as a filter on both contents of response and file.
  #   get(:action, params)
  #   assert_response_equal_file(
  #     "#{path}/expected_response.html",
  #     "#{path}/alternate_expected_response.html") do |str|
  #     str.strip_squeeze.downcase
  #   end
  #
  def assert_response_equal_file(*files, &block)
    body = @response.body_parts.join("\n")
    body = fix_encoding(body, files) if encoding_included?(files)
    assert_string_equal_file(body, *files, &block)
  end

  def encoding_included?(files)
    files.first.is_a?(Array)
  end

  # Work-around for Net::HTTP issue that causes incorrect response-body encoding
  def fix_encoding(body, files)
    encoding = files.first.second
    body.force_encoding(encoding)
  end

  # Send a general request of any type.  Check login_required and check_user
  # heuristics if appropriate.  Check that the resulting redirection or
  # rendered template is correct.
  #
  # method::        HTTP request method.  Defaults to "GET".
  # action::        Action/page requested, e.g., :show_observation.
  # params::        Hash of parameters to pass in.  Defaults to {}.
  # user::          User name.  Defaults to "rolf" (user #1, a reviewer).
  # password::      Password.  Defaults to "testpassword".
  # alt_user::      Alternate user name.  Defaults to "rolf" or "mary",
  #                 whichever is different.
  # alt_password::  Password for alt user.  Defaults to "testpassword".
  # require_login:: Check result if no user logged in.
  # require_user::  Check result if wrong user logged in.
  # result::        Expected result if everything is correct.
  #
  #   # POST the edit_name form: requires standard login; redirect to
  #   # show_name if it succeeds.
  #   assert_request(
  #     method: "POST",
  #     action: "edit_name",
  #     params: params,
  #     require_login: :login,
  #     result: ["show_name"]
  #   )
  #
  #   # Make sure only logged-in users get to post this page, and that it
  #   # render the template of the same name when it succeeds.
  #   post_requires_login(:edit_name, id: 1)
  #
  def assert_request(args)
    method       = args[:method] || :get
    action       = args[:action] || raise("Missing action!")
    params       = args[:params] || {}
    user         = args[:user] || "rolf"
    password     = args[:password] || "testpassword"
    alt_user     = args[:alt_user] || (user == "mary" ? "rolf" : "mary")
    alt_password = args[:alt_password] || "testpassword"

    logout

    # Make sure it fails if not logged in at all.
    if (result = args[:require_login])
      result = :login if result == true
      send(method, action, params: params)
      assert_response(result, "No user: ")
    end

    # Login alternate user, and make sure that also fails.
    if (result = args[:require_user])
      login(alt_user, alt_password)
      send(method, action, params: params)
      assert_response(result, "Wrong user (#{alt_user}): ")
    end

    # Finally, login correct user and let it do its thing.
    login(user, password)
    send("#{method}_with_dump", action, params)
    assert_response(args[:result])
  end

  # Check response of a request.  There are several different types:
  #
  #   # The old style continues to work.
  #   assert_response(200)
  #   assert_response(:success)
  #
  #   # Expect it to render a given template (success).
  #   assert_response("template")
  #
  #   # Expect a redirect to particular observation
  #   assert_response( {controller: observer, action: show_observation, id: 1 })
  #   assert_response( {action: show_observation, id: 1 })
  #
  #   # Expect a redirection to site index.
  #   assert_response(controller: "observer", action: "index")
  #
  #   # These also expect a redirection to site index.
  #   assert_response(["index"])
  #   assert_response(["observer", "index"])
  #
  #   # Short-hand for common redirects:
  #   assert_response(:index)   => /observer/list_rss_logs
  #   assert_response(:login)   => /account/login
  #   assert_response(:welcome) => /account/welcome
  #
  #   # Lastly, expect redirect to full explicit URL.
  #   assert_response("http://bogus.com")
  #
  def assert_response(arg, msg = "")
    return unless arg

    if arg == :success || arg == :redirect || arg.is_a?(Integer)
      super
    else
      # Put together good error message telling us exactly what happened.
      code = @response.response_code
      if @response.successful?
        got = ", got #{code} rendered <#{@request.fullpath}>."
      elsif @response.not_found?
        got = ", got #{code} missing (?)"
      elsif @response.redirect?
        url = @response.redirect_url.sub(/^http:..test.host/, "")
        got = ", got #{code} redirect to <#{url}>."
      else
        got = ", got #{code} body is <#{extract_error_from_body}>."
      end

      # Add flash notice to potential error message.
      flash_notice = get_last_flash.to_s.strip_squeeze
      if flash_notice != ""
        got += "\nFlash message: <#{flash_notice[1..-1].html_to_ascii}>."
      end

      # Now check result.
      if arg.is_a?(Array)
        if arg.length == 1
          if arg[0].is_a?(Hash)
            msg += "Expected redirect to <#{url_for(arg[0])}>" + got
            assert_redirected_to(url_for(arg[0]), msg)
          else
            controller = @controller.controller_name
            msg += "Expected redirect to <#{controller}/#{arg[0]}>" + got
            # assert_redirected_to({action: arg[0]}, msg)
            assert_redirected_to(%r{/#{controller}/#{arg[0]}}, msg)
          end
        else
          msg += "Expected redirect to <#{arg[0]}/#{arg[1]}}>" + got
          # assert_redirected_to({ controller: arg[0], action: arg[1] }, msg)
          assert_redirected_to(%r{/#{arg[0]}/#{arg[1]}}, msg)
        end
      elsif arg.is_a?(Hash)
        url = @controller.url_for(arg).sub(/^http:..test.host./, "")
        msg += "Expected redirect to <#{url}>" + got
        # assert_redirect_match(arg, @response, @controller, msg)
        assert_redirected_to(arg, msg)
      elsif arg.is_a?(String) && arg.match(%r{^\w+://})
        msg += "Expected redirect to <#{arg}>" + got
        assert_equal(arg, @response.redirect_url, msg)
      elsif arg.is_a?(String)
        controller = @controller.controller_name
        msg += "Expected it to render <#{controller}/#{arg}>" + got
        super(:success, msg)
        assert_template(arg.to_s, msg)
      elsif arg == :index
        msg += "Expected redirect to <observer/list_rss_logs>" + got
        assert_redirected_to({ controller: "observer",
                               action: "list_rss_logs" }, msg)
      elsif arg == :login
        msg += "Expected redirect to <account/login>" + got
        assert_redirected_to({ controller: "account", action: "login" }, msg)
      elsif arg == :welcome
        msg += "Expected redirect to <account/welcome>" + got
        assert_redirected_to({ controller: "account", action: "login" }, msg)
      else
        raise "Invalid response type expected: [#{arg.class}: #{arg}]\n"
      end
    end
  end

  def assert_action(action, partials)
    if partials
      if partials.is_a?(Array)
        assert_action_partials(action, partials)
      else
        assert_redirected_to(action: action, partial: partials)
      end
    else
      assert_redirected_to(action: action)
    end
  end

  def assert_action_partials(action, partials)
    partials.each do |p|
      assert_template(action, partial: p)
    end
  end

  def assert_redirect_match(partial, response, controller, _msg)
    mismatches = find_mismatches(partial, response.redirect_url)
    if mismatches[:controller].to_s == controller.controller_name.to_s
      mismatches.delete(:controller)
    elsif mismatches.member?(:controller)
      print "assert_redirect_match: #{partial}\n"
      print "assert_redirect_match: #{response.redirect_url}\n"
    end
    assert_equal({}, mismatches, "Mismatched partial hash: #{mismatches}")
  end

  def find_mismatches(partial, full)
    mismatches = {}
    partial.each do |k, v|
      f = full[k] || full[k.to_s]
      f = full[k.to_sym] if f.nil? && k.respond_to?(:to_sym)
      mismatches[k] = v if f.to_s != v.to_s
    end
    mismatches
  end

  # Check default value of a form field.
  def assert_input_value(id, expect_val)
    message = "Didn't find any inputs '#{id}'."
    assert_select("input##{id}, select##{id}") do |elements|
      if elements.length > 1
        message = "Found more than one input '#{id}'."
      elsif elements.length == 1
        message = if /^<select/.match?(elements.first.to_s)
                    check_select_value(elements.first, expect_val, id)
                  else
                    check_input_value(elements.first.to_s, expect_val, id)
                  end
      end
    end
    assert(message.nil?, message)
  end

  def check_select_value(elem, expect_val, id)
    if expect_val.nil?
      assert_select(elem, "option[selected]", { count: 0 },
                    "Expected :#{id} not to have any options selected")
      nil
    else
      assert_select(elem, "option[selected]", { count: 1 },
                    "Expected :#{id} to have one option selected") do |opts|
        return check_input_value(opts.first.to_s, expect_val, id)
      end
    end
  end

  def check_input_value(elem, expect_val, id)
    match = elem.match(/value=('[^']*'|"[^"]*")/)
    actual_val = match ? CGI.unescapeHTML(match[1].sub(/^.(.*).$/, '\\1')) : ""
    actual_val = "" if elem =~ /type=['"]?checkbox/ && elem !~ / checked[ >]/
    return if actual_val == expect_val.to_s

    "Input '#{id}' has wrong value, " \
    "expected <#{expect_val}>, got <#{actual_val}>"
  end

  # Check existence and value of a texarea
  def assert_textarea_value(id, expect_val)
    message = "Didn't find any inputs '#{id}'."
    assert_select("textarea##{id}") do |elements|
      if elements.length > 1
        message = "Found more than one input '#{id}'."
      elsif elements.length == 1
        actual_val = CGI.unescapeHTML(elements.first.children.map(&:to_s).
                         join("")).strip
        message = if actual_val != expect_val.to_s
                    "Input '#{id}' has wrong value, " \
                    "expected <#{expect_val}>, got <#{actual_val}>"
                  end
      end
    end
    assert(message.nil?, message)
  end

  # Check the state of a checkbox.  Parameters: +id+ is element id,
  # +state+ can be:
  #
  #   :no_field
  #   :checked
  #   :unchecked
  #   :checked_but_disabled
  #   :unchecked_but_disabled
  #
  def assert_checkbox_state(id, state)
    case state
    when :checked_but_disabled
      assert_select("input##{id}", 1)
      assert_select("input##{id}[checked=checked]", 1)
      assert_select("input##{id}[disabled=disabled]", 1)
    when :unchecked_but_disabled
      assert_select("input##{id}", 1)
      assert_select("input##{id}[checked=checked]", 0)
      assert_select("input##{id}[disabled=disabled]", 1)
    when :checked, true
      assert_select("input##{id}", 1)
      assert_select("input##{id}[checked=checked]", 1)
      assert_select("input##{id}[disabled=disabled]", 0)
    when :unchecked, false
      assert_select("input##{id}", 1)
      assert_select("input##{id}[checked=checked]", 0)
      assert_select("input##{id}[disabled=disabled]", 0)
    when :no_field
      assert_select("input##{id}", 0)
    else
      raise "Invalid state in check_project_checks: #{state.inspect}"
    end
  end

  # Check presence and value of notes textareas.  Example:
  #   assert_page_has_correct_notes( expect_areas: { Cap: "red", Other: "" } )
  #   assert_page_has_correct_notes( klass: Species_list,
  #                                  expect_areas: { Other: "" })
  def assert_page_has_correct_notes_areas(klass: Observation, expect_areas: {})
    expect_areas.each do |key, val|
      id = klass.notes_part_id(key.to_s.tr(" ", "_"))
      assert_textarea_value(id, val)
    end
  end
end
