# frozen_string_literal: true

require("test_helper")

module Tab::CollectionNumber
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @collection_number = collection_numbers(:detailed_unknown_coll_num_one)
      @observation = @collection_number.observations.first
    end

    def test_show_without_observation
      tab = Tab::CollectionNumber::Show.new(
        collection_number: @collection_number
      )

      assert_equal(@collection_number.format_name.t, tab.title)
      assert_equal(@collection_number.show_link_args, tab.path)
      assert_equal(@collection_number, tab.model)
    end

    def test_show_with_observation
      tab = Tab::CollectionNumber::Show.new(
        collection_number: @collection_number, observation: @observation
      )

      assert(tab.path[:q].present?)
    end

    def test_new
      tab = Tab::CollectionNumber::New.new(observation: @observation)

      assert_equal(:create_collection_number.l, tab.title)
      assert_equal(
        routes.new_collection_number_path(observation_id: @observation.id),
        tab.path
      )
      assert_equal(:add, tab.html_options[:icon])
      assert_equal(CollectionNumber, tab.model)
    end

    def test_edit_back_to_observation
      tab = Tab::CollectionNumber::Edit.new(
        collection_number: @collection_number, observation: @observation
      )

      assert_equal(:edit_collection_number.l, tab.title)
      assert_equal(
        routes.edit_collection_number_path(
          id: @collection_number.id, back: @observation.id
        ),
        tab.path
      )
    end

    def test_edit_back_to_show
      tab = Tab::CollectionNumber::Edit.new(
        collection_number: @collection_number
      )

      assert_equal(
        routes.edit_collection_number_path(
          id: @collection_number.id, back: :show
        ),
        tab.path
      )
    end

    def test_destroy
      tab = Tab::CollectionNumber::Destroy.new(
        collection_number: @collection_number
      )

      assert_equal(:delete_collection_number.l, tab.title)
      assert_equal(@collection_number, tab.path)
      assert_equal(:destroy, tab.html_options[:button])
      assert_equal(@collection_number, tab.model)
    end

    def test_back_to_index
      tab = Tab::CollectionNumber::BackToIndex.new(
        collection_number: @collection_number
      )

      assert_equal(:edit_collection_number_back_to_index.l, tab.title)
      assert_equal(@collection_number.index_link_args, tab.path)
      assert_equal(@collection_number, tab.model)
    end
  end
end
