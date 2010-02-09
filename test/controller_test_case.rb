#
#  = Controller Test Helpers
#
#  TestCase to use with ActionController tests.  This includes a number of
#  useful helpers and assertions that apply only to controller tests.
#
#  == Request helpers
#  reget::                      Resets request and calls +get+.
#  login::                      Login a user.
#  logout::                     Logout current user.
#  make_admin::                 Make current user an admin and turn on admin mode.
#  get_with_dump::              Send GET, no login required.
#  requires_login::             Send GET, login required.
#  requires_user::              Send GET, certain user must be logged in.
#  post_with_dump::             Send POST, no login required.
#  post_requires_login::        Send POST, login required.
#  post_requires_user::         Send POST, certain user must be logged in.
#  html_dump::                  Dump response body to file for W3C validation.
#  get_without_clearing_flash::  Wrapper: calls +get+ without clearing flash errors.
#  post_without_clearing_flash:: Wrapper: calls +post+ without clearing flash errors.
#
#  == HTML Helpers
#  get_last_flash::             Retrieve the current list of errors or last set rendered.
#  url_for::                    Get URL for +link_to+ style Hash of args.
#  extract_links::              Get Array of show_object links on page.
#  extract_error_from_body::    Extract error and stacktrace from 500 response body.
#
#  == HTML Assertions
#  assert_link_in_html::        A given link exists.
#  assert_no_link_in_html::     A given link does not exist.
#  assert_form_action::         A form posting to a given action exists.
#  assert_response_equal_file:: Response body is same as copy in a file.
#  assert_request::             Check heuristics of an arbitrary request.
#  assert_response::            Check that last request resulted in a given redirect / render.
#  assert_flash::               Assert that an error was rendered or is pending.
#
################################################################################

class ControllerTestCase < ActionController::TestCase

  ##############################################################################
  #
  #  :section: Request helpers
  #
  ##############################################################################

  # Make sure we clear out the last errors before each request.
  def get(*args)
    if @without_clearing_flash
      @without_clearing_flash = nil
    elsif session.is_a?(ActionController::TestSession)
      flash[:rendered_notice] = nil
      session[:notice] = nil
    end
    super
  end

  # Make sure we clear out the last errors before each request.
  def post(*args)
    if @without_clearing_flash
      @without_clearing_flash = nil
    elsif session.is_a?(ActionController::TestSession)
      flash[:rendered_notice] = nil
      session[:notice] = nil
    end
    super
  end

  # Second "get" won't update request_uri, so we must reset the request.
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
  def login(user='rolf', password='testpassword')
    user = User.authenticate(user, password)
    assert(user, "Failed to authenticate user <#{user}> with password <#{password}>.")
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
  def make_admin(user='rolf', password='testpassword')
    user = login(user, password)
    @request.session[:admin] = true
    if !user.admin
      user.admin = 1
      user.save
    end
    return user
  end

  # Send a GET request, and save the result in a file for w3c validation.
  #
  #   # Send request, but ignore response.
  #   get(:action, params)
  #
  #   # Send request, and save response in ../html/action_0.html.
  #   get_with_dump(:action, params)
  #
  def get_with_dump(page, params={})
    get(page, params)
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
  def post_with_dump(page, params={})
    post(page, params)
    html_dump(page, @response.body, params)
  end

  # Send GET request to a page that should require login.
  #
  #   # Make sure only logged-in users get to see this page.
  #   requires_login(:edit_name, :id => 1)
  #
  def requires_login(page, *args)
    either_requires_either(:get, page, nil, *args)
  end

  # Send POST request to a page that should require login.
  #
  #   # Make sure only logged-in users get to post this page.
  #   post_requires_login(:edit_name, :id => 1)
  #
  def post_requires_login(page, *args)
    either_requires_either(:post, page, nil, *args)
  end

  # Send GET request to a page that should require a specific user.
  #
  #   # Make sure only reviewers can see this page (non-reviewers get
  #   # redirected to "show_location").
  #   requires_user(:review_authors, :show_location, :id => 1)
  #   requires_user(:review_authors, [:location, :show_location], :id => 1)
  #
  def requires_user(*args)
    either_requires_either(:get, *args)
  end

  # Send POST request to a page that should require login.
  #
  #   # Make sure only owner can edit observation (non-owners get
  #   # redirected to "show_observation").
  #   post_requires_user(:edit_obs, :show_obs, :notes => 'new notes')
  #   post_requires_user(:edit_obs, [:observer, :show_obs], :notes => 'new notes')
  #
  def post_requires_user(*args)
    either_requires_either(:post, *args)
  end

  # Helper used by the blah_requires_blah methods.
  # method::        [Request method: :get or :post. -- Supplied automatically by all four "public" methods.]
  # page::          Name of action.
  # altpage::       [Name of page redirected to if user wrong. -- Only include in +requires_user+ and +post_requires_user+.]
  # params::        Hash of parameters for action.
  # stay_on_page::  Does it render template of same name as action if succeeds?
  # username::      Which user should be logged in (default is 'rolf').
  # password::      Which password should it try to use (default is 'testpassword').
  #
  #   # Make sure only logged-in users get to see this page, and that it
  #   # render the template of the same name when it succeeds.
  #   requires_login(:edit_name, :id => 1)
  #
  #   # Make sure only logged-in users get to post this page, but that it
  #   # renders the template of a different name (or redirects) on success.
  #   post_requires_login(:edit_name, :id => 1, false)
  #
  #   # Make sure only reviewers can see this page (non-reviewers get
  #   # redirected to "show_location"), and that it renders
  #   # the template of the same name when it succeeds.
  #   requires_user(:review_authors, {:id => 1}, :show_location)
  #
  #   # Make sure only owner can edit observation (non-owners get
  #   # redirected to "show_observation"), and that it redirects to
  #   # "show_observation" when it succeeds (last argument).
  #   post_requires_user(:edit_observation, {:notes => 'new notes'},
  #     :show_observation, [:show_observation])
  #
  #   # Even more general case where second case renders a template:
  #   post_requires_user(:action, params,
  #     {:controller => controller1, :action => :access_denied, ...},
  #     :success_template)
  #
  #   # Even more general case where both cases redirect:
  #   post_requires_user(:action, params,
  #     {:controller => controller1, :action => :access_denied, ...},
  #     {:controller => controller2, :action => :succeeded, ...})
  #
  def either_requires_either(method, page, altpage, params={},
                             username='rolf', password='testpassword')
    assert_request(
      :method        => method,
      :action        => page,
      :params        => params,
      :user          => username,
      :password      => password,
      :require_login => :login,
      :require_user  => altpage ? [altpage].flatten : nil
    )
  end

  # The whole purpose of this is to create a directory full of sample HTML
  # files that we can run the W3C validator on -- this has nothing to do with
  # debugging!  This happens automatically if following directory exists:
  #
  #   RAILS_ROOT/../html
  #
  # Files are created:
  #
  #   show_user_0.html
  #   show_user_1.html
  #   show_user_2.html
  #   etc.
  #
  def html_dump(label, html, params)
    html_dir = '../html'
    if File.directory?(html_dir) and html[0..11] != '<html><body>'
      file_name = "#{html_dir}/#{label}.html"
      count = 0
      while File.exists?(file_name)
        file_name = "#{html_dir}/#{label}_#{count}.html"
        count += 1
        if count > 100
          raise(RangeError, "More than 100 files found with a label of '#{label}'")
        end
      end
      print "Creating html_dump file: #{file_name}\n"
      file = File.new(file_name, "w")
      # show_params(file, params, "params")
      file.write(html)
      file.close
    end
  end

  # Add the hash of parameters to the dump file for diagnostics.
  def show_params(file, hash, prefix)
    if hash.is_a?(Hash)
      hash.each {|k,v| show_params(file, v, "#{prefix}[#{k.to_s}]")}
    else
      file.write("#{prefix} = [#{hash.to_s}]<br>\n")
    end
  end

  ##############################################################################
  #
  #  :section: HTML Helpers
  #
  ##############################################################################

  # Get the errors rendered in the last request, or current set of errors if
  # redirected.
  def get_last_flash
    flash[:rendered_notice] || session[:notice]
  end

  # Return URL for +link_to+ style Hash of parameters.
  def url_for(args={})
    # By default expect relative links.  Allow caller to override by
    # explicitly setting :only_path => false.
    args[:only_path] = true if !args.has_key?(:only_path)
    URI.unescape(@controller.url_for(args))
  end

  # Extract links from the HTML response body that match any of a number of
  # conditions, and return them as an Array of objects with these properties.
  # url::        Full url of the link.
  # controller:: Controller part of url (if relative).
  # action::     Action part of url (if relative).
  # id::         ID part of the url (if present).
  # anchor::     Anchor part of the url (if present).
  # label::      Text of link as displayed in browser.
  #
  # Conditions can be any of these properties.  Accepts a String/Symbol,
  # Regexp, or +nil+.  All require full match, except +label+, which can be
  # wrapped in HTML tags and/or white-space.
  #
  #   # Make sure a link called "Some Text" exists and has the correct url.
  #   link = extract_links(:label => /Some Text/).first
  #   expect = url_for(:action => 'show_name', :id => 123)
  #   assert_equal(expect, link.url)
  #
  #   # Check links in list_names index.
  #   ids = extract_links(:action => 'show_name').map(&:id)
  #   assert_equal([1, 2, 3], ids)
  #
  #   # You can use it as an iterator, too.
  #   links = extract_links do |link|
  #     break if link.label =~ /Stop Here/
  #   end
  #
  def extract_links(args={})
    result = []
    # Allow caller to specify URL condition as Hash of args as for +link_to_.
    if args[:url].is_a?(Hash)
      args[:url] = url_for(args[:url])
    end

    # Iterate over all links, in order.
    html = @response.body
    while html.match(/<a href="([^"]+)"[^<>]*>(.*?)<\/a>/)
      html, url, label = $', $1, $2
      url = URI.unescape(url).html_to_ascii

      # Parse URL.
      if url.match(/^\/(\w+)\/(\w+)\/(\d+)/)
        controller, action, id = $1, $2, $3.to_i
      elsif url.match(/^\/(\w+)\/(\w+)/)
        controller, action, id = $1, $2, nil
      else
        controller, action, id = nil, nil, nil
      end
      if url.match(/#(.*)$/)
        anchor = $1
      else
        anchor = nil
      end

      # Make sure it matches any conditions passed in.
      passed = true
      for arg, val in [
        [:url, url],
        [:controller, controller],
        [:action, action],
        [:id, id],
        [:anchor, anchor],
      ]
        if args.has_key?(arg) and
           not case (val2 = args[arg])
           when NilClass
             val.nil?
           when Regexp
             val.to_s.match(val2)
           when String, Symbol
             val.to_s == val2.to_s
           end
          passed = false
          break
        end
      end

      # Allow label to be embedded in HTML tags, with some whitespace, but
      # require it to be the first text inside the <a> tag.
      if passed and args[:label] and
         !label.match(/^(\s*<\w+[^\\<>]+>)*\s*#{args[:label]}(\s*<\/\w+[^<>]+>)*\s*$/)
        passed = false
      end

      # Return all the links that pass.
      if passed
        link = Wrapper.new(
          :label      => label,
          :url        => url,
          :controller => controller,
          :action     => action,
          :id         => id,
          :anchor     => anchor
        )

        # Let caller do custom filter.
        if !block_given? or yield(link)
          result << link
        end
      end
    end
    return result
  end

  # Extract error message and backtrace from Rails's 500 response.  This should
  # be obsolete now that all the test controllers re-raise exceptions.  But
  # just in case, here it is...
  def extract_error_from_body
    str = @response.body
    str.gsub!(/<pre>.*?<.pre>/m) {|x| x.gsub(/\s*\n/, "<br>")}
    str.sub!(/^.*?<p>/m, '')
    str.sub!(/<.div>.*/m, '')
    str.sub!(/<div.*<div.*?>/m, '')
    str.sub!(/<p><code>RAILS.*?<.p>/, '')
    str.gsub!(/<p><.p>/m, '')
    str.gsub!(/\s+/m, ' ')
    str.gsub!('<br>', "\n")
    str.gsub!('</p>', "\n\n")
    str.gsub!(': <pre>', "\n")
    str.gsub!(/<.*?>/, '')
    str.gsub!(/^ */, '')
    str.gsub!(/\n\n+/, "\n\n")
    str.sub!(/\A\s*/, "\n")
    str.sub!(/\s*\Z/, "\n")
  end

  ##############################################################################
  #
  #  :section: HTML assertions
  #
  ##############################################################################

  # Assert the LACK of existence of a given link in the response body, and
  # check that it points to the right place.
  def assert_no_link_in_html(label, msg=nil)
    clean_our_backtrace do
      extract_links(:label => label) do |link|
        assert_block(build_message(msg, "Expected HTML *not* to contain link called <?>.", label)) {false}
      end
      assert_block('') { true } # to count the assertion
    end
  end

  # Assert the existence of a given link in the response body, and check
  # that it points to the right place.
  def assert_link_in_html(label, url_opts, msg=nil)
    clean_our_backtrace do
      url = url_for(url_opts)
      found_it = false
      extract_links(:label => label) do |link|
        if link.url != url
          assert_block(build_message(msg, "Expected <?> link to point to <?>, instead it points to <?>", label, url, url2)) {false}
        else
          found_it = true
          break
        end
      end
      if found_it
        assert_block('') { true } # to count the assertion
      else
        assert_block(build_message(msg, "Expected HTML to contain link called <?>.", label)) {false}
      end
    end
  end

  # Assert that a form exists which posts to the given url.
  def assert_form_action(url_opts, msg=nil)
    clean_our_backtrace do
      url_opts[:only_path] = true if url_opts[:only_path].nil?
      url = URI.unescape(@controller.url_for(url_opts))
      # Find each occurrance of <form action="blah" method="post">.
      found_it = false
      found = {}
      @response.body.split("<form action").each do |str|
        if str =~ /^="([^"]*)" [^>]*method="post"/
          url2 = URI.unescape($1).gsub('&amp;', '&')
          if url == url2
            found_it = true
            break
          end
          found[url2] = 1
        end
      end
      if found_it
        assert_block("") { true } # to count the assertion
      elsif found.keys
        assert_block(build_message(msg, "Expected HTML to contain form that posts to <?>, but only found these: <?>.", url, found.keys.sort.join('>, <'))) { false }
      else
        assert_block(build_message(msg, "Expected HTML to contain form that posts to <?>, but found nothing at all.", url)) { false }
      end
    end
  end

  # Assert that a response body is same as contents of a given file.
  # Pass in a block to use as a filter on both contents of response and file.
  #
  #   assert_response_equal_file(
  #     "#{path}/expected_response.html",
  #     "#{path}/alternate_expected_response.html") do |str|
  #     str.strip_squeeze.downcase
  #   end
  #
  def assert_response_equal_file(*files, &block)
    clean_our_backtrace do
      assert_string_equal_file(@response.body.clone, *files, &block)
    end
  end

  # Send a general request of any type.  Check login_required and check_user
  # heuristics if appropriate.  Check that the resulting redirection or
  # rendered template is correct.
  #
  # method::        HTTP request method.  Defaults to :get.
  # action::        Action/page requested, e.g., :show_observation.
  # params::        Hash of parameters to pass in.  Defaults to {}.
  # user::          User name.  Defaults to 'rolf' (user #1, a reviewer).
  # password::      Password.  Defaults to 'testpassword'.
  # alt_user::      Alternate user name.  Defaults to 'rolf' or 'mary', whichever is different.
  # alt_password::  Password for alt user.  Defaults to 'testpassword'.
  # require_login:: Check result if no user logged in.
  # require_user::  Check result if wrong user logged in.
  # result::        Expected result if everything is correct.
  #
  #   # POST the edit_name form: requires standard login; redirect to
  #   # show_name if it succeeds.
  #   assert_request(
  #     :method        => :post,
  #     :action        => 'edit_name',
  #     :params        => params,
  #     :require_login => :login,
  #     :result        => ['show_name']
  #   )
  #
  #   # Make sure only logged-in users get to post this page, and that it
  #   # render the template of the same name when it succeeds.
  #   post_requires_login(:edit_name, :id => 1)
  #
  def assert_request(args)
    clean_our_backtrace do
      method       = args[:method]       || :get
      action       = args[:action]       || raise("Missing action!")
      params       = args[:params]       || {}
      user         = args[:user]         || 'rolf'
      password     = args[:password]     || 'testpassword'
      alt_user     = args[:alt_user]     || (user == 'mary' ? 'rolf' : 'mary')
      alt_password = args[:alt_password] || 'testpassword'

      logout

      # Make sure it fails if not logged in at all.
      if result = args[:require_login]
        result = :login if result == true
        send(method, action, params)
        assert_response(result, "No user: ")
      end

      # Login alternate user, and make sure that also fails.
      if result = args[:require_user]
        login(alt_user, alt_password)
        send(method, action, params)
        assert_response(result, "Wrong user (#{alt_user}): ")
      end

      # Finally, login correct user and let it do its thing.
      login(user, password)
      send("#{method}_with_dump", action, params)
      assert_response(args[:result])
    end
  end

  # Check response of a request.  There are several different types:
  #
  #   # The old style continues to work.
  #   assert_response(200)
  #   assert_response(:success)
  #
  #   # Expect it to render a given template (success).
  #   assert_response('template')
  #
  #   # Expect a redirection to site index.
  #   assert_response(:controller => 'observer', :action => 'index')
  #
  #   # These also expect a redirection to site index.
  #   assert_response(['index'])
  #   assert_response(['observer', 'index'])
  #
  #   # Short-hand for common redirects:
  #   assert_response(:index)   => /observer/list_rss_logs
  #   assert_response(:login)   => /account/login
  #   assert_response(:welcome) => /account/welcome
  #
  def assert_response(arg, msg='')
    if arg
      clean_our_backtrace do
        if arg == :success || arg == :redirect || arg.is_a?(Fixnum)
          super
        else

          # Put together good error message telling us exactly what happened.
          code = @response.response_code
          if @response.success?
            got = ", got #{code} rendered <#{@response.rendered_file}>."
          elsif @response.missing?
            got = ", got #{code} missing (?)"
          elsif @response.redirect?
            url = @response.redirect_url.sub(/^http:..test.host./, '')
            got = ", got #{code} redirect to <#{url}>."
          else
            got = ", got #{code} body is <#{extract_error_from_body}>."
          end

          # Add flash notice to potential error message.
          flash = get_last_flash.to_s.strip_squeeze
          if flash != ''
            got += "\nFlash message: <#{flash[1..-1].html_to_ascii}>."
          end

          # Now check result.
          if arg.is_a?(Array)
            if arg.length == 1
              controller = @controller.controller_name
              msg += "Expected redirect to <#{controller}/#{arg[0]}>" + got
              assert_redirected_to({:action => arg[0]}, msg)
            else
              msg += "Expected redirect to <#{arg[0]}/#{arg[1]}}>" + got
              assert_redirected_to({:controller => arg[0], :action => arg[1]}, msg)
            end
          elsif arg.is_a?(Hash)
            url = @controller.url_for(arg).sub(/^http:..test.host./, '')
            msg += "Expected redirect to <#{url}>" + got
            assert_redirected_to(arg, msg)
          elsif arg.is_a?(String)
            controller = @controller.controller_name
            msg += "Expected it to render <#{controller}/#{arg}>" + got
            super(:success, msg)
            assert_template(arg.to_s, msg)
          elsif arg == :index
            msg += "Expected redirect to <observer/list_rss_logs>" + got
            assert_redirected_to({:controller => 'observer', :action => 'list_rss_logs'}, msg)
          elsif arg == :login
            msg += "Expected redirect to <account/login>" + got
            assert_redirected_to({:controller => 'account', :action => 'login'}, msg)
          elsif arg == :welcome
            msg += "Expected redirect to <account/welcome>" + got
            assert_redirected_to({:controller => 'account', :action => 'login'}, msg)
          else
            raise "Invalid response type expected: [#{arg.class}: #{arg}]\n"
          end
        end
      end
    end
  end

  # Assert that an error was rendered or is pending.
  def assert_flash(expect, msg='')
    clean_our_backtrace do
      if got = get_last_flash
        lvl = got[0,1].to_i
        got = got[1..-1]
      end
      if !expect && got
        assert_equal(nil, got, msg + "Shouldn't have been any flash errors.")
      elsif expect && !got
        assert_equal(expect, nil, msg + "Expected a flash error.")
      elsif expect.is_a?(Fixnum)
        assert_equal(expect, lvl, msg + "Wrong flash error level.")
      elsif expect.is_a?(Regexp)
        assert_match(expect, got, msg + "Got the wrong flash error(s).")
      else
        assert_equal(expect, got, msg + "Got the wrong flash error(s).")
      end
    end
  end
end
