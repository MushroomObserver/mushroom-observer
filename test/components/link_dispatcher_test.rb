# frozen_string_literal: true

require("test_helper")

class LinkDispatcherTest < ComponentTestCase
  # When no `type:` key is passed, `self.new` falls through to `super`
  # and returns a plain `Components::Link` instance (not a subclass).
  def test_no_type_kwarg_returns_link_instance
    result = Components::Link.new

    assert_instance_of(Components::Link, result)
  end

  # An unknown `type:` key raises ArgumentError immediately.
  def test_unknown_type_raises_argument_error
    assert_raises(ArgumentError) do
      Components::Link.new(type: :bogus_unknown_type)
    end
  end
end
