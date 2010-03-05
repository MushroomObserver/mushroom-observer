# Test typical sessions of user who never creates an account or contributes.

require File.dirname(__FILE__) + '/../boot'

class LurkerTest < IntegrationTestCase
  def test_poke_around
    open_session do
      # Start at index.
      get('/')
      assert_template('observer/list_rss_logs')

      # Click on first observation.
      click_on(:href => /^.\d+/, :in => :results)
      assert_template('observer/show_observation')
      push_page

      # Click on the first image.
      click_on(:label => :image, :in => 'div.show_images')
      click_on(:label => :image, :href => '/image/show_original')

      # Go back to observation and click on "About...".
      go_back
      click_on(:label => 'About', :href => '/name/show_name')
      assert_template('name/show_name')
      push_page(:name)

      # Take a look at the distribution map.
      click_on(:label => 'Distribution Map', :in => :tabs)
      assert_template('name/map')

      # Check out a few links from left-hand panel.
      click_on(:label => 'How To Use',     :in => :left_panel)
      click_on(:label => 'Español',        :in => :left_panel)
      click_on(:label => 'Contribuidores', :in => :left_panel)
      click_on(:label => 'English',        :in => :left_panel)
      click_on(:label => 'List Projects',  :in => :left_panel)
      click_on(:label => 'Comments',       :in => :left_panel)
      click_on(:label => 'Site Stats',     :in => :left_panel)
    end
  end

  def test_obs_at_location
    open_session do
      # Start at distribution map for Fungi.
      get('/name/map/1')

      # Get a list of locations shown on map. (Only one so goes to show_loc.)
      click_on(:label => 'Show Locations', :in => :tabs)
      assert_template('location/show_location')

      # Get a list of observations from there.  (Several so goes to index.)
      click_on(:label => 'Observations at this Location', :in => :tabs)
      assert_template('observer/list_observations')
      save_results = get_links('div.results a[href^=?]', /^.\d+/)
      query_params = parse_query_params(save_results.first)

      # Try sorting differently.
      click_on(:label => 'Sort by Date', :in => :tabs)
      results = get_links('div.results a[href^=?]', /^.\d+/)
      assert_equal(save_results.sort, results.sort)
      click_on(:label => 'Sort by User', :in => :tabs)
      results = get_links('div.results a[href^=?]', /^.\d+/)
      assert_equal(save_results.sort, results.sort)
      click_on(:label => 'Sort by Name', :in => :tabs)
      results = get_links('div.results a[href^=?]', /^.\d+/)
      assert_equal(save_results.sort, results.sort)

      # Go to first observation, and try stepping back and forth.
      click_on(:href => /^.\d+/, :in => :results)
      save_path = path
      assert_equal(query_params, parse_query_params)
      click_on(:label => '« Prev', :in => :tabs)
      assert_flash(/there are no more observations/i)
      assert_equal(save_path, path)
      assert_equal(query_params, parse_query_params)
      click_on(:label => 'Next »', :in => :tabs)
      assert_flash(nil)
      assert_equal(query_params, parse_query_params)
      save_path = path
      click_on(:label => 'Next »', :in => :tabs)
      assert_flash(nil)
      assert_equal(query_params, parse_query_params)
      click_on(:label => '« Prev', :in => :tabs)
      assert_flash(nil)
      assert_equal(query_params, parse_query_params)
      assert_equal(save_path, path,
                   "Went next then prev, should be back where we started.")
      click_on(:label => 'Index', :href => '/observer/index', :in => :tabs)
      results = get_links('div.results a[href^=?]', /^.\d+/)
      assert_equal(query_params, parse_query_params(results.first))
      assert_equal(save_results, results,
                   "Went to show_obs, screwed around, then back to index. " +
                   "But the results were not the same when we returned.")
    end
  end

  def test_show_observation
    open_session do
      # Start with Observation #2 since it has everything.
      get('/2')
      push_page

      # Check out the RSS log.
      save_path = path
      click_on(:label => 'Show Log')
      click_on(:label => 'Show Observation')
      assert_equal(save_path, path,
                   "Went to RSS log and returned, expected to be the same.")

      # Mary has done several things to it (observation itself, naming, comment).
      assert_select('a[href^=/observer/show_user/2]', :minimum => 3)
      click_on(:label => 'Mary Newbie')
      assert_template('observer/show_user')

      # Check out location.
      go_back
      click_on(:label => 'Burbank, Los Angeles')
      assert_template('location/show_location')

      # Check out species list.
      go_back
      click_on(:label => 'List of mysteries')
      assert_template('species_list/show_species_list')
      # (Make sure observation #2 is shown somewhere.)
      assert_select('a[href^=/2?]')

      # Click on name.
      go_back
      # (Should be at least two links to show the name Fungi.)
      assert_select('a[href^=/name/show_name/1]', :minimum => 2)
      click_on(:label => /About.*Fungi/)
      # (Make sure observation #2 is shown somewhere.)
      assert_select('a[href^=/2?]')

      # And lastly there are some images.
      go_back
      assert_select('a[href^=/image/show_image]', :minimum => 2)
      click_on(:label => :image, :href => '/image/show_image')
      # (Make sure observation #2 is shown somewhere.)
      assert_select('a[href^=/2?]')
    end
  end

  def test_search
    open_session do
      get('/')

      # Search for a name.  (Only one.)
      form = do_form('form[action$=search]')
      form.edit_field('pattern', 'Coprinus comatus')
      form.submit('Names')
      assert_match(/^.name.show_name.2\?/, path)

      # Search for observations of that name.  (Only one.)
      form.submit('Observations')
      assert_match(/^.3\?/, path)

      # Search for images of the same thing.  (Still only one.)
      form.submit('Images')
      assert_match(/^.image.show_image.5\?/, path)
      
      # There should be no locations of that name, though.
      form.submit('Locations')
      assert_template('location/list_locations')
      assert_flash(/no.*found/i)
      assert_select('div.results a[href]', false)

      # This should give us just about all the locations.
      form.edit_field('pattern', 'california OR canada')
      form.submit('Locations')
      assert_select('div.results a[href]') do |links|
        labels = links.map {|l| l.to_s.html_to_ascii}
        assert(labels.any? {|l| l.match(/Canada$/)},
               "Expected one of the results to be in Canada.\n" +
               "Found these: #{labels.inspect}")
        assert(labels.any? {|l| l.match(/USA$/)},
               "Expected one of the results to be in the US.\n" +
               "Found these: #{labels.inspect}")
      end
    end
  end
end
