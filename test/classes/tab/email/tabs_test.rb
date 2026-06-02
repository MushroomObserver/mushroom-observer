# frozen_string_literal: true

require("test_helper")

module Tab::Email
  class CollectionsTest < UnitTestCase
    def setup
      @name = names(:fungi)
    end

    def test_name_change_request
      tabs = Tab::Email::NameChangeRequest.new(name: @name).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end

    def test_merge_request
      tabs = Tab::Email::MergeRequest.new(old_obj: @name).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end
  end
end
