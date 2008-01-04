ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'

class Test::Unit::TestCase
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
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = true

  # Add more helper methods to be used by all tests here...
end


def html_dump(label, html)
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
    file.write(html)
    file.close
  end
end

def get_with_dump(page, params={})
  get(page, params)
  html_dump(page, @response.body)
end

# Do a login
def login(user='rolf', password='testpassword')
  user = User.authenticate(user, password)
  assert(user)
  session['user'] = user
end

def requires_login(page, params={}, stay_on_page=true, user='rolf', password='testpassword')
  get(page, params) # Expect redirect
  assert_redirected_to(:controller => "account", :action => "login")
  login(user, password)
  get_with_dump(page, params)
  if stay_on_page
    assert_response :success
    assert_template page.to_s
  end
end

def requires_user(page, alt_page, params={}, stay_on_page=true, username='rolf', password='testpassword')
  alt_username = 'mary'
  if username == 'mary':
    alt_username = 'rolf'
  end
  get(page, params) # Expect redirect
  assert_redirected_to(:controller => "account", :action => "login")
  login(alt_username, 'testpassword')
  get(page, params) # Expect redirect
  if alt_page.class == Array
    assert_redirected_to(:controller => alt_page[0], :action => alt_page[1])
  else
    assert_template alt_page.to_s
  end
  
  login(username, password)
  get_with_dump(page, params)
  if stay_on_page
    assert_response :success
    assert_template page.to_s
  end
end
