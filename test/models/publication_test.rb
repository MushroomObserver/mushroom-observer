# frozen_string_literal: true

require("test_helper")

class PublicationTest < UnitTestCase
  def test_valid_with_user_and_full
    pub = Publication.new(user: users(:rolf), full: "Some Publication")
    assert(pub.valid?)
  end

  def test_invalid_without_user
    pub = Publication.new(full: "Some Publication")
    assert_not(pub.valid?)
  end

  def test_invalid_without_full
    pub = Publication.new(user: users(:rolf))
    assert_not(pub.valid?)
  end

  def test_full_has
    spam = publications(:spam_pub)

    assert_includes(Publication.full_has("spam"), spam)
    assert_not_includes(Publication.full_has("nonexistent_phrase"), spam)
  end
end
