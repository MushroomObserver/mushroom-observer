# frozen_string_literal: true

require("test_helper")

# test MO extensions to Ruby's Array class
class ArrayExtensionsTest < UnitTestCase
  def test_to_boolean_hash
    assert_equal({}, [].to_boolean_hash)
    assert_equal({ "a" => true, "b" => true, "c" => true },
                 %w[a b c].to_boolean_hash)
  end

  def test_safe_join
    array1 = ["<p>foo</p>".html_safe, "<p>bar</p>"]
    array2 = ["<p>foo</p>".html_safe, "<p>bar</p>".html_safe]

    assert_equal("<p>foo</p>&lt;br /&gt;&lt;p&gt;bar&lt;/p&gt;",
                 array1.safe_join("<br />"),
                 "safe_joiner returned incorrect value")
    assert_equal("<p>foo</p><br /><p>bar</p>",
                 array2.safe_join("<br />".html_safe),
                 "safe_joiner returned incorrect value")
  end
end
