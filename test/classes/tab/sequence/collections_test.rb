# frozen_string_literal: true

require("test_helper")

module Tab::Sequence
  class CollectionsTest < UnitTestCase
    def setup
      @sequence = sequences(:deposited_sequence)
      @observation = @sequence.observation
    end

    def test_show_actions
      tabs = Tab::Sequence::ShowActions.new(sequence: @sequence).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end

    def test_form
      tabs = Tab::Sequence::Form.new(back_object: @observation).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end
  end
end
