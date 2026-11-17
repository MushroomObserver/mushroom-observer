# frozen_string_literal: true

require("test_helper")

class Components::BadgeTest < ComponentTestCase
  def test_sibling_marker_variant_returns_sibling_marker_instance
    result = Components::Badge.new(variant: :sibling_marker, number: 1)

    assert_instance_of(Components::Badge::SiblingMarker, result)
  end

  # When no `variant:` key is passed, `self.new` falls through to
  # `super` and returns a plain `Components::Badge` instance (not a
  # subclass) -- matches `Components::Link`'s dispatcher.
  def test_no_variant_kwarg_returns_badge_instance
    result = Components::Badge.new

    assert_instance_of(Components::Badge, result)
  end

  # An unknown `variant:` key raises ArgumentError immediately.
  def test_unknown_variant_raises_argument_error
    assert_raises(ArgumentError) do
      Components::Badge.new(variant: :bogus_unknown_variant)
    end
  end
end
