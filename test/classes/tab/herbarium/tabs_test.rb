# frozen_string_literal: true

require("test_helper")

# Covers all 5 Tab::Herbarium::* single Tab POROs. Each test
# asserts title and path (via route helpers, not literal URLs) and
# any non-default attribute (alt_title, model).
module Tab::Herbarium
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @herbarium = herbaria(:nybg_herbarium)
    end

    def test_new
      tab = Tab::Herbarium::New.new

      assert_equal(:create_herbarium.l, tab.title)
      assert_equal(routes.new_herbarium_path, tab.path)
      assert_equal("new_herbarium", tab.alt_title)
      assert_equal(Herbarium, tab.model)
    end

    def test_list_all
      tab = Tab::Herbarium::ListAll.new

      assert_equal(:herbarium_index_list_all_herbaria.l, tab.title)
      assert_equal(routes.herbaria_path, tab.path)
      assert_equal(Herbarium, tab.model)
    end

    def test_return
      tab = Tab::Herbarium::Return.new(herbarium: @herbarium)

      assert_equal(:cancel_and_show.t(type: :herbarium), tab.title)
      assert_equal(routes.herbarium_path(@herbarium), tab.path)
      assert_equal(@herbarium, tab.model)
    end

    def test_nonpersonal_index_with_and_without_q_param
      bare = Tab::Herbarium::NonpersonalIndex.new.path
      with_q = Tab::Herbarium::NonpersonalIndex.new(q_param: "X").path

      assert_equal(routes.herbaria_path(nonpersonal: true), bare)
      assert_equal(routes.herbaria_path(nonpersonal: true, q: "X"), with_q)
    end

    def test_nonpersonal_index_alt_title
      tab = Tab::Herbarium::NonpersonalIndex.new

      assert_equal(:herbarium_index.t, tab.title)
      assert_equal("nonpersonal_herbaria_index", tab.alt_title)
      # Plain InternalLink (not Model variant) — no model.
      assert_nil(tab.model)
    end

    def test_labeled_nonpersonal_index
      tab = Tab::Herbarium::LabeledNonpersonalIndex.new

      assert_equal(:herbarium_index_nonpersonal_herbaria.l, tab.title)
      assert_equal(routes.herbaria_path(nonpersonal: true), tab.path)
      assert_nil(tab.model)
    end
  end
end
