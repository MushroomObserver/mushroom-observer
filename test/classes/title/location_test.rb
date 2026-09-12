# frozen_string_literal: true

require("test_helper")

class Title::LocationTest < UnitTestCase
  def test_page_title_no_user
    loc = locations(:albion)

    assert_equal(loc.display_name(nil), Title.for(loc).page_title)
  end

  # Location has two display formats -- postfix ("City, State, USA")
  # for most users, scientific ("USA, State, City") when the user's
  # `location_format` pref says so. `display_name(user)` switches
  # between `name`/`scientific_name` based on that pref, so page_title
  # needs covering under both, not just the default.
  def test_page_title_postfix_format_user
    loc = locations(:albion)
    user = users(:rolf) # postfix (default) format

    assert_equal(loc.name, Title.for(loc).page_title(user))
  end

  def test_page_title_scientific_format_user
    loc = locations(:albion)
    user = users(:roy) # scientific format

    assert_equal(loc.scientific_name, Title.for(loc).page_title(user))
  end

  def test_document_title
    loc = locations(:albion)

    assert_equal(loc.text_name, Title.for(loc).document_title)
  end
end
