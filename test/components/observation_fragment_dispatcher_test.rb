# frozen_string_literal: true

require("test_helper")

class ObservationFragmentDispatcherTest < ComponentTestCase
  def test_unknown_type_raises_argument_error
    assert_raises(ArgumentError) do
      Components::ObservationFragment.new(type: :bogus_unknown_type)
    end
  end

  def test_missing_type_raises_argument_error
    assert_raises(ArgumentError) { Components::ObservationFragment.new }
  end
end
