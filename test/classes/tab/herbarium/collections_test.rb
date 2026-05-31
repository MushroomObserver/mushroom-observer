# frozen_string_literal: true

require("test_helper")

module Tab::Herbarium
  class CollectionsTest < UnitTestCase
    def setup
      @herbarium = herbaria(:nybg_herbarium)
    end

    # Index: conditional on query[:nonpersonal]. When set, includes
    # ListAll (back to full); otherwise LabeledNonpersonalIndex
    # (offer the nonpersonal filter). Always appends New.

    def test_index_no_query
      tabs = Tab::Herbarium::Index.new.to_a

      assert_equal(
        [Tab::Herbarium::LabeledNonpersonalIndex, Tab::Herbarium::New],
        tabs.map(&:class)
      )
    end

    def test_index_with_nonpersonal_query
      query = Query.lookup(:Herbarium, nonpersonal: true)
      tabs = Tab::Herbarium::Index.new(query: query).to_a

      assert_equal(
        [Tab::Herbarium::ListAll, Tab::Herbarium::New],
        tabs.map(&:class)
      )
    end

    def test_show
      tabs = Tab::Herbarium::Show.new.to_a

      assert_equal([Tab::Herbarium::NonpersonalIndex], tabs.map(&:class))
    end

    def test_form_new
      tabs = Tab::Herbarium::FormNew.new.to_a

      assert_equal([Tab::Herbarium::NonpersonalIndex], tabs.map(&:class))
    end

    def test_form_edit
      tabs = Tab::Herbarium::FormEdit.new(herbarium: @herbarium).to_a

      assert_equal(
        [Tab::Herbarium::Return, Tab::Herbarium::NonpersonalIndex],
        tabs.map(&:class)
      )
    end

    def test_curator_request
      tabs = Tab::Herbarium::CuratorRequest.new(herbarium: @herbarium).to_a

      assert_equal(
        [Tab::Herbarium::Return, Tab::Herbarium::NonpersonalIndex],
        tabs.map(&:class)
      )
    end
  end
end
