require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class SiteDataTest < UnitTestCase

  def test_create
    obj = SiteData.new
    obj.get_site_data
    obj.get_user_data(@rolf.id)
    obj.get_all_user_data
  end
end
