# frozen_string_literal: true

require("test_helper")

class Components::BadgeTest < ComponentTestCase
  def test_count_type_returns_count_instance
    result = Components::Badge.new(type: :count, count: 1)

    assert_instance_of(Components::Badge::Count, result)
  end

  def test_id_type_returns_id_instance
    result = Components::Badge.new(type: :id, size: :sm)

    assert_instance_of(Components::Badge::ID, result)
  end

  def test_sibling_marker_type_returns_sibling_marker_instance
    result = Components::Badge.new(type: :sibling_marker, number: 1)

    assert_instance_of(Components::Badge::SiblingMarker, result)
  end

  # When no `type:` key is passed, `self.new` falls through to
  # `super` and returns a plain `Components::Badge` instance (not a
  # subclass) -- matches `Components::Link`'s dispatcher.
  def test_no_type_kwarg_returns_badge_instance
    result = Components::Badge.new

    assert_instance_of(Components::Badge, result)
  end

  # An unknown `type:` key raises ArgumentError immediately.
  def test_unknown_type_raises_argument_error
    assert_raises(ArgumentError) do
      Components::Badge.new(type: :bogus_unknown_type)
    end
  end
end
