require File.dirname(__FILE__) + '/../boot'

class SiteDataTest < Test::Unit::TestCase
  fixtures :add_image_test_logs
  fixtures :comments
  fixtures :images
  fixtures :images_observations
  fixtures :licenses
  fixtures :locations
  fixtures :names
  fixtures :naming_reasons
  fixtures :namings
  fixtures :observations
  fixtures :observations_species_lists
  fixtures :past_locations
  fixtures :past_names
  fixtures :rss_logs
  fixtures :species_lists
  fixtures :synonyms
  fixtures :users
  fixtures :votes

  def test_create
    obj = SiteData.new
    obj.get_site_data
    obj.get_user_data(@rolf.id)
    obj.get_all_user_data
  end
end
