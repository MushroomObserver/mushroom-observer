# frozen_string_literal: true

require("test_helper")

class ModalDispatcherTest < ComponentTestCase
  # When no `type:` key is passed, `self.new` falls through to `super`
  # and returns a plain `Components::Modal` instance (not a subclass).
  def test_no_type_kwarg_returns_modal_instance
    result = Components::Modal.new(id: "m")

    assert_instance_of(Components::Modal, result)
  end

  def test_type_confirm_returns_confirm_instance
    assert_instance_of(Components::Modal::Confirm,
                       Components::Modal.new(type: :confirm))
  end

  def test_type_progress_spinner_returns_progress_spinner_instance
    assert_instance_of(Components::Modal::ProgressSpinner,
                       Components::Modal.new(type: :progress_spinner))
  end

  def test_unknown_type_raises_argument_error
    assert_raises(ArgumentError) do
      Components::Modal.new(type: :bogus_unknown_type)
    end
  end
end
