ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'

# Used to test image uploads.  The normal "live" params[:upload] is
# essentially a file with a "content_type" field added to it.  This is
# meant to take its place.
class FilePlus < File
  attr_accessor :content_type
  def size
    File.size(path)
  end
end

# Create subclasses of StringIO that has a content_type member to replicate the
# dynamic method addition that happens in Rails cgi.rb.
class StringIOPlus < StringIO
  attr_accessor :content_type
end

# Re-raise errors caught by the controller.
class ApplicationController; def rescue_action(e) raise e end; end

################################################################################
#
#  = Test Helpers
#
#  Methods in this class are available to all the unit and functional tests.
#  There are a bunch of helpers for testing GET/POST request heuristics, and
#  there are a bunch of specialized assertions.
#
#  == Request Helpers
#  login::                      Login a user.
#  logout::                     Logout current user.
#  make_admin::                 Make current user an admin and turn on admin mode.
#  get_with_dump::              Send GET, no login required.
#  requires_login::             Send GET, login required.
#  requires_user::              Send GET, certain user must be logged in.
#  post_with_dump::             Send POST, no login required.
#  post_requires_login::        Send POST, login required.
#  post_requires_user::         Send POST, certain user must be logged in.
#  assert_request::             Check heuristics of an arbitrary request.
#  assert_response::              Check that last request resulted in a given redirect / render.
#  html_dump::                  Dump response body to file for W3C validation.
#  extract_error_from_body::    Extract error and stacktrace from 500 response body.
#
#  == Assertions
#  assert_list_equal::          Compare two lists by mapping and sorting elements.
#  assert_obj_list_equal::      Compare two lists of objects, comparing ids.
#  assert_user_list_equal::     Compare two lists of User's.
#  assert_name_list_equal::     Compare two lists of Name's.
#  assert_link_in_html::        A given link exists.
#  assert_form_action::         A form posting to a given action exists.
#  assert_response_equal_file:: Response body is same as copy in a file.
#  assert_string_equal_file::   A string is same as contents of a file.
#  assert_email::               Check the properties of a QueuedEmail.
#
#  == XML Assertions
#  assert_xml_exists::          An element exists.
#  assert_xml_none::            An element doesn't exist.
#  assert_xml_name::            An element is a certain type.
#  assert_xml_attr::            An element has a certain attribute.
#  assert_xml_text::            An element contains a certain text value.
#  dump_xml::                   Dump out XML tree for diagnostics.
#
#  == Fixtures
#  clear_unused_fixtures::      Clear all tables we aren't using fixtures for.
#  local_fixtures::             Load fixture(s) for a single test.
#
################################################################################

class Test::Unit::TestCase
  # Register standard teardown hook.
  teardown :application_teardown

  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  use_instantiated_fixtures  = true

  # I lifted this from action_controller/assertions.rb.  It cleans up the
  # backtrace so that it appears as if assertions occurred in the unit test
  # that called the assertions in this file.
  def clean_our_backtrace(&block)
    yield
  rescue Test::Unit::AssertionFailedError => error
    framework_path = Regexp.new(File.expand_path("#{File.dirname(__FILE__)}/test_helper"))
    error.backtrace.reject! { |line| File.expand_path(line) =~ framework_path }
    raise
  end

  # Get a list of all database tables.
  def all_tables
    if !defined?(@@all_tables)
      @@all_tables = User.connection.select_values('SHOW TABLES') -
                     ['migration_schemas']
    end
    @@all_tables
  end

  # Delete everything in the tables whose fixtures we haven't bothered to
  # include.  This lets us get away with only included fixtures that are
  # absolutely necessary, speeding up tests dramatically (?)
  def clear_unused_fixtures
    for table in all_tables - fixture_table_names.map(&:to_s)
      User.connection.execute("DELETE FROM `#{table}`")
    end
  end

  # Include fixtures for a single test.
  #
  #   def test_blah
  #     local_fixtures :past_locations
  #     ...
  #   end
  #
  def local_fixtures(*tables)
    for table in tables
      self.class.try_to_load_dependency table.to_s.singularize
    end
    fixtures = Fixtures.create_fixtures(fixture_path, tables)
    fixtures = [fixtures] if fixtures.instance_of?(Fixtures)
    for fixture in fixtures
      Fixtures.instantiate_fixtures(self, fixture.table_name, fixture, true)
    end
  end

  # Standard teardown to run after every test.
  def application_teardown
    if File.exists?(IMG_DIR)
      FileUtils.rm_rf(IMG_DIR)
    end
    clear_unused_fixtures
  end

  # ----------------------------
  #  :section: Request Helpers
  # ----------------------------

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
    clean_our_backtrace do
      either_requires_either(:get, page, nil, *args)
    end
  end

  # Send POST request to a page that should require login.
  #
  #   # Make sure only logged-in users get to post this page.
  #   post_requires_login(:edit_name, :id => 1)
  #
  def post_requires_login(page, *args)
    clean_our_backtrace do
      either_requires_either(:post, page, nil, *args)
    end
  end

  # Send GET request to a page that should require a specific user.
  #
  #   # Make sure only reviewers can see this page (non-reviewers get
  #   # redirected to "show_location").
  #   requires_user(:review_authors, :show_location, :id => 1)
  #   requires_user(:review_authors, [:location, :show_location], :id => 1)
  #
  def requires_user(*args)
    clean_our_backtrace do
      either_requires_either(:get, *args)
    end
  end

  # Send POST request to a page that should require login.
  #
  #   # Make sure only owner can edit observation (non-owners get
  #   # redirected to "show_observation").
  #   post_requires_user(:edit_obs, :show_obs, :notes => 'new notes')
  #   post_requires_user(:edit_obs, [:observer, :show_obs], :notes => 'new notes')
  #
  def post_requires_user(*args)
    clean_our_backtrace do
      either_requires_either(:post, *args)
    end
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
      action       = args[:action]
      params       = args[:params]       || {}
      user         = args[:user]         || 'rolf'
      password     = args[:password]     || 'testpassword'
      alt_user     = args[:alt_user]     || (user == 'mary' ? 'rolf' : 'mary')
      alt_password = args[:alt_password] || 'testpassword'

      # Make sure it fails if not logged in at all.
      if result = args[:require_login]
        logout
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
      flash[:notice] = nil
      flash[:notice_level] = 0
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
  #   assert_response(:template)
  #
  #   # Expect a redirection to site index.
  #   assert_response(:controller => 'observer', :action => 'index')
  #
  #   # These also expect a redirection to site index.
  #   assert_response(['index'])
  #   assert_response(['observer', 'index'])
  #
  #   # Short-hand for expecting redirection to login page.
  #   assert_response(:login)
  #
  def assert_response(arg, msg='')
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
        if flash[:notice].to_s.strip_squeeze != ''
          got += "\nFlash message: <#{flash[:notice].to_s.html_to_ascii}>."
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
        elsif arg == :login
          msg += "Expected redirect to <account/login>" + got
          assert_redirected_to({:controller => 'account', :action => 'login'}, msg)
        elsif arg
          controller = @controller.controller_name
          msg += "Expected it to render <#{controller}/#{arg}.rhtml>" + got
          super(:success, msg)
          assert_template(arg.to_s, msg)
        end
      end
    end
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

  # ----------------------------
  #  :section: Assertions
  # ----------------------------

  # Compare two lists by mapping their elements, then sorting.  By default it
  # just maps their elements to strings.
  #
  #   assert_list_equal([@rolf,@mary], name.authors, &:login)
  #
  def assert_list_equal(expect, got, msg=nil, &block)
    clean_our_backtrace do
      block ||= :to_s.to_proc
      assert_equal(expect.map(&block).sort, got.map(&block).sort, msg)
    end
  end

  # Compare two lists of objects of the same type by comparing their ids.
  #
  #   assert_obj_list_equal([img1,img2], obs.images)
  #
  def assert_obj_list_equal(expect, got, msg=nil)
    clean_our_backtrace do
      assert_list_equal(expect, got, msg, &:id)
    end
  end

  # Compare two lists of User's by comparing their logins.
  #
  #   assert_user_list_equal([@rolf,@mary], name.authors)
  #
  def assert_user_list_equal(expect, got, msg=nil)
    clean_our_backtrace do
      assert_list_equal(expect, got, msg, &:login)
    end
  end

  # Compare two lists of Name's by comparing their search_names.
  #
  #   assert_name_list_equal([old_name,new_name], old_name.synonym.names)
  #
  def assert_name_list_equal(expect, got, msg=nil)
    clean_our_backtrace do
      assert_list_equal(expect, got, msg, &:search_name)
    end
  end

  # Assert the existence of a given link in the response body, and check
  # that it points to the right place.
  def assert_link_in_html(label, url_opts, msg=nil)
    clean_our_backtrace do
      url_opts[:only_path] = true if url_opts[:only_path].nil?
      url = URI.unescape(@controller.url_for(url_opts))
      # Find each occurrance of "label", then make sure it is inside a link...
      # i.e. that there is no </a> between it and the previous <a href="blah"> tag.
      found_it = false
      @response.body.gsub('&nbsp;',' ').split(label).each do |str|
        # Find the last <a> tag in the string preceding the label.
        atag = str[str.rindex("<a ")..-1]
        if !atag.include?("</a>")
          if atag =~ /^<a href="([^"]*)"/
            url2 = URI.unescape($1).html_to_ascii
            if url == url2
              found_it = true
              break
            else
              assert_block(build_message(msg, "Expected <?> link to point to <?>, instead it points to <?>", label, url, url2)) {false}
            end
          end
        end
      end
      if found_it
        assert_block("") { true } # to count the assertion
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
        assert_block(build_message(msg, "Expected HTML to contain form that posts to <?>, but only found these: <?>.", url, found.keys.sort.join(">, <"))) { false }
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

  # Assert that a string is same as contents of a given file.  Pass in a block
  # to use as a filter on both contents of response and file.
  #
  #   assert_string_equal_file(@response.body,
  #     "#{path}/expected_response.html",
  #     "#{path}/alternate_expected_response.html") do |str|
  #     str.strip_squeeze.downcase
  #   end
  #
  def assert_string_equal_file(str, *files)
    clean_our_backtrace do
      result = false
      msg    = nil

      # Check string against each file, looking for at least one that matches.
      body1  = str
      body1  = yield(body1) if block_given?
      for file in files
        body2 = File.open(file) {|fh| fh.read}
        body2 = yield(body2) if block_given?
        if body1 == body2
          # Stop soon as we find one that matches.
          result = true
          break
        elsif !msg
          # Write out expected (old) and received (new) files for debugging purposes.
          File.open(file + '.old', 'w') {|fh| fh.write(body2)}
          File.open(file + '.new', 'w') {|fh| fh.write(body1)}
          msg = "File #{file} wrong:\n" + `diff #{file}.old #{file}.new`
          File.delete(file + '.old') if File.exists?(file + '.old')
        end
      end

      if result
        # Clean out old files from previous failure(s).
        for file in files
          File.delete(file + '.new') if File.exists?(file + '.new')
        end
      else
        assert(false, msg)
      end
    end
  end

  # Test whether the n-1st queued email matches.  For example:
  #
  #   assert_email(0,
  #     :flavor  => 'QueuedEmail::Comment',
  #     :from    => @mary,
  #     :to      => @rolf,
  #     :comment => @comment_on_minmal_unknown.id
  #   )
  #
  def assert_email(n, args)
    clean_our_backtrace do
      email = QueuedEmail.find(:first, :offset => n)
      assert(email)
      for arg in args.keys
        case arg
        when :flavor
          assert_equal(args[arg], email.flavor, "Flavor is wrong")
        when :from
          assert_equal(args[arg].id, email.user_id, "Sender is wrong")
        when :to
          assert_equal(args[arg].id, email.to_user_id, "Recipient is wrong")
        when :note
          assert_equal(args[arg], email.get_note, "Value of note is wrong")
        else
          assert_equal(args[arg], email.get_integer(arg) || email.get_string(arg), "Value of #{arg} is wrong")
        end
      end
    end
  end

  # ----------------------------
  #  :section:  XML Assertions
  # ----------------------------

  # Retrieve the element identified by key, e.g.,
  #
  #   get_xml_element('/root/child/grand-child')
  #
  # If any of the children are numbers, it gets the Nth child at that level.
  #
  def get_xml_element(key)
    assert(@doc, "XML response is nil!")
    key.sub(/^\//,'').split('/').inject(@doc) do |elem, key|
      elem = elem.elements[key.match(/^\d+$/) ? key.to_i : key]
      assert(elem, "XML response missing element \"#{key}\".")
      elem
    end
  end

  # Assert that a given element does NOT exist.
  #
  #   assert_xml_exists('/response', @response.body)
  #
  def assert_xml_exists(key, msg=nil)
    clean_our_backtrace do
      assert(@doc, "XML response is nil!")
      result = key.sub(/^\//,'').split('/').inject(@doc) do |elem, key|
        elem = elem.elements[key.match(/^\d+$/) ? key.to_i : key]
        assert(nil, msg || "XML response should have \"#{key}\".") if !elem
        elem
      end
    end
  end

  # Assert that a given element does NOT exist.
  #
  #   assert_xml_none('/response/errors')
  #
  def assert_xml_none(key, msg=nil)
    clean_our_backtrace do
      assert(@doc, "XML response is nil!")
      result = key.sub(/^\//,'').split('/').inject(@doc) do |elem, key|
        elem = elem.elements[key.match(/^\d+$/) ? key.to_i : key]
        return if !elem
        elem
      end
      assert_nil(result, msg || "XML response shouldn't have \"#{key}\".")
    end
  end

  # Assert that a given element is of the given type.
  #
  #   assert_xml_name('comment', '/response/results/1')
  #
  def assert_xml_name(val, key, msg=nil)
    clean_our_backtrace do
      _assert_xml(val, get_xml_element(key).name,
                  msg || "XML element \"#{key}\" should be a <#{val}>.")
    end
  end

  # Assert that a given element has a given attribute.
  #
  #   assert_xml_attr(1234, '/response/results/1/id')
  #
  def assert_xml_attr(val, key, msg=nil)
    clean_our_backtrace do
      key.match(/^(.*)\/(.*)/)
      key, attr = $1, $2
      _assert_xml(val, get_xml_element(key).attributes[attr],
                  msg || "XML element \"#{key}\" should have attribute \"#{val}\".")
    end
  end

  # Assert that a given element has a given value.
  #
  #   assert_xml_text('rolf', '/response/results/1/login')
  #
  def assert_xml_text(val, key, msg=nil)
    clean_our_backtrace do
      _assert_xml(val, get_xml_element(key).text,
                  msg || "XML element \"#{key}\" should be \"#{val}\".")
    end
  end

  # Private helper method used in XML assertions above:
  #
  #   _assert_xml(10, @doc.elements['/response/results'].attributes['number'])
  #   _assert_xml('rolf', @doc.elements['/response/user/login'].text)
  #   _assert_xml(/\d\d-\d\d-\d\d/, @doc.elements['/response/script_date'].text)
  #
  def _assert_xml(val, str, msg=nil)
    if val.is_a?(Regexp)
      assert(str.to_s.gsub(/^\s+|\s+$/,'').gsub(/\s+/,' ').match(val), msg)
    else
      assert_equal(val.to_s.gsub(/^\s+|\s+$/,'').gsub(/\s+/,' '),
                   str.to_s.gsub(/^\s+|\s+$/,'').gsub(/\s+/,' '), msg)
    end
  end

  # Dump out XML tree.
  def dump_xml(e, indent='')
    print "#{indent}#{e.name}"
    if e.has_attributes?
      attrs = []
      e.attributes.each do |a,v|
        attrs << "#{a}=#{v}"
      end
      print "(#{attrs.join(' ')})"
    end
    if e.has_text? && e.text =~ /\S/
      txt = e.text.gsub(/^\s+|\s+$/, '').gsub(/\s+/, ' ')
      txt = "\"#{txt}\"" if txt.match(' ')
      print " = #{txt}"
    end
    print "\n"
    if e.has_elements?
      e.elements.each do |child|
        dump_xml(child, indent + '  ')
      end
    end
  end
end
