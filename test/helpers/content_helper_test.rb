# frozen_string_literal: true

require("test_helper")

# test the content helpers
module ContentHelperTest
  def test_escape_textiled_string
    textile = "**Bold**"
    escaped = "&lt;div class=&quot;textile&quot;&gt;&lt;p&gt;&lt;b&gt;Bold" \
              "&lt;/b&gt;&lt;/p&gt;&lt;/div&gt;"
    assert_equal(escaped, escape_html(textile.tpl))
  end
end
