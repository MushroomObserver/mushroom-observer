# frozen_string_literal: true

require("test_helper")

class ImageFragmentDispatcherTest < ComponentTestCase
  def test_unknown_type_raises_argument_error
    assert_raises(ArgumentError) do
      Components::ImageFragment.new(type: :bogus_unknown_type)
    end
  end

  def test_missing_type_raises_argument_error
    assert_raises(ArgumentError) { Components::ImageFragment.new }
  end
end
