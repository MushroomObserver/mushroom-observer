require File.dirname(__FILE__) + '/../test_helper'
require 'observer_controller'
require 'fileutils'

# Re-raise errors caught by the controller.
class ObserverController; def rescue_action(e) raise e end; end

class CurrentTest < Test::Unit::TestCase
  fixtures :observations
  fixtures :users
  fixtures :comments
  fixtures :images
  fixtures :images_observations
  fixtures :species_lists
  fixtures :observations_species_lists
  fixtures :names
  fixtures :rss_logs
  fixtures :synonyms
  fixtures :licenses

  def setup
    @controller = ObserverController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def teardown
  end

  # Pages that require login
  def login(user='rolf', password='testpassword')
    get :news 
    user = User.authenticate(user, password)
    assert(user)
    session['user'] = user
  end

  def requires_login(page, params={}, stay_on_page=true, user='rolf', password='testpassword')
    get(page, params) # Expect redirect
    assert_redirected_to(:controller => "account", :action => "login")
    user = User.authenticate(user, password)
    assert(user)
    session['user'] = user
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
    get(page, params)
    assert_redirected_to(:controller => "account", :action => "login")
    user = User.authenticate(alt_username, 'testpassword')
    assert(user)
    session['user'] = user
    get(page, params)
    if alt_page.class == Array
      assert_redirected_to(:controller => alt_page[0], :action => alt_page[1])
    else
      assert_template alt_page.to_s
    end
    
    login username, password
    get(page, params)
    if stay_on_page
      assert_response :success
      assert_template page.to_s
    end
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
  
  def test_trivial
    assert_equal(1+1, 2)
  end

  # Need to create the fixtures to have a naming owned by the observer that has 'No Opinion'
  def test_show_observation_no_opinion
    # login as rolf
    user = User.authenticate("rolf", "testpassword")
    assert(user)
    @request.session['user'] = user
    
    # ensure that rolf owns @obs_with_no_opinion
    assert(user == @strobilurus_diminutivus_obs.user)
    
    get_with_dump :show_observation, :id => @strobilurus_diminutivus_obs.id
    assert_response :success
    assert_template 'show_observation'
  end

end

class StillToCome
  # no deprecation
end
