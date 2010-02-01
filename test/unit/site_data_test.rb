require File.dirname(__FILE__) + '/../boot'

class SiteDataTest < Test::Unit::TestCase

  def test_create
    obj = SiteData.new
    obj.get_site_data
    obj.get_user_data(@rolf.id)
    obj.get_all_user_data
  end
end
