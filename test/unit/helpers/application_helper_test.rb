require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
#  include ApplicationHelper
 
  test "Textile markup should be escaped" do
  	textile = "**Bold**"
  	escaped = "&lt;div class=&quot;textile&quot;&gt;&lt;p&gt;&lt;b&gt;Bold&lt;/b&gt;&lt;/p&gt;&lt;/div&gt;"
		assert_equal escaped, escape_markup(textile)
  end
end