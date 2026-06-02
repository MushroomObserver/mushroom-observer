# frozen_string_literal: true

require("test_helper")

module Tab::CollectionNumber
  class CollectionsTest < UnitTestCase
    def setup
      @collection_number = collection_numbers(:detailed_unknown_coll_num_one)
      @observation = @collection_number.observations.first
    end

    def test_index_actions_no_observation
      tabs = Tab::CollectionNumber::IndexActions.new.to_a

      assert_empty(tabs)
    end

    def test_index_actions_with_observation
      tabs = Tab::CollectionNumber::IndexActions.new(
        observation: @observation
      ).to_a

      assert_equal(
        [Tab::Object::Return, Tab::CollectionNumber::New],
        tabs.map(&:class)
      )
    end

    def test_form_new
      tabs = Tab::CollectionNumber::FormNew.new(
        observation: @observation
      ).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end

    def test_form_edit_back_to_index
      tabs = Tab::CollectionNumber::FormEdit.new(
        collection_number: @collection_number,
        back: "index", back_object: @observation
      ).to_a

      assert_equal([Tab::CollectionNumber::BackToIndex], tabs.map(&:class))
    end

    def test_form_edit_back_to_object
      tabs = Tab::CollectionNumber::FormEdit.new(
        collection_number: @collection_number,
        back: "show", back_object: @observation
      ).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end
  end
end
