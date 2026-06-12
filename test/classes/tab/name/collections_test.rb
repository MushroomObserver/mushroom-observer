# frozen_string_literal: true

require("test_helper")

module Tab::Name
  class CollectionsTest < UnitTestCase
    def setup
      @name = names(:agaricus_campestris)
    end

    def test_form_new
      tabs = Tab::Name::FormNew.new.to_a

      assert_equal([Tab::Name::Index], tabs.map(&:class))
    end

    def test_form_edit
      tabs = Tab::Name::FormEdit.new(name: @name).to_a

      assert_equal([Tab::Object::Return, Tab::Object::Index],
                   tabs.map(&:class))
    end

    def test_version_actions
      tabs = Tab::Name::VersionActions.new(name: @name).to_a

      assert_equal([Tab::Object::Show], tabs.map(&:class))
      assert_equal(:show_name.t(name: @name.display_name),
                   tabs.first.title)
    end

    def test_forms_return
      tabs = Tab::Name::FormsReturn.new(name: @name).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end

    def test_index_actions_no_query
      tabs = Tab::Name::IndexActions.new.to_a

      # Just `New` when no has_observations filter (the
      # Related::Query bridge is also nil when current_query is nil).
      assert_includes(tabs.map(&:class), Tab::Name::New)
      assert_not_includes(tabs.map(&:class), Tab::Name::All)
    end

    def test_index_actions_with_has_observations_query
      query = ::Query.lookup(:Name, has_observations: true)

      stub_for_related = ->(*) { false }
      ::Query.stub(:related?, stub_for_related) do
        tabs = Tab::Name::IndexActions.new(query: query,
                                           controller: nil).to_a

        assert_includes(tabs.map(&:class), Tab::Name::New)
        assert_includes(tabs.map(&:class), Tab::Name::All)
      end
    end

    def test_map_actions
      query = ::Query.lookup(:Observation)

      stub_for_related = ->(*) { false }
      ::Query.stub(:related?, stub_for_related) do
        tabs = Tab::Name::MapActions.new(name: @name, query: query,
                                         controller: nil).to_a

        # Just Object::Show when the related bridges are nil.
        assert_equal([Tab::Object::Show], tabs.map(&:class))
        assert_equal(
          :name_map_about.t(name: @name.display_name),
          tabs.first.title
        )
      end
    end
  end
end
