# frozen_string_literal: true

require("test_helper")

module Herbaria
    # Test display of all Herbaria
    class AllsControllerTest < FunctionalTestCase
    # ---------- Helpers ----------

    def nybg
      herbaria(:nybg_herbarium)
    end

    def fundis
      herbaria(:fundis_herbarium)
    end

    def dicks_personal
      herbaria(:dick_herbarium)
    end

    def herbarium_params
      {
        name: "",
        personal: "",
        code: "",
        place_name: "",
        email: "",
        mailing_address: "",
        description: ""
      }.freeze
    end

    def field_museum
      herbaria(:field_museum)
    end

    # ---------- Actions to Display data (index, show, etc.) -------------------

    def test_index
      get(:index)

      assert_response(:success)
      assert_select("#title-caption", { text: "#{:HERBARIA.l} by Name" },
                    "index should display #{:HERBARIA.l} by Name")
      Herbarium.find_each do |herbarium|
        assert_select(
          "a[href *= '#{herbarium_path(herbarium)}']", true,
          "Herbarium Index missing link to #{herbarium.format_name})"
        )
      end
    end

    def test_index_merge_source_links_presence_rolf
      assert_true(nybg.can_edit?(rolf)) # rolf is a curator
      assert_true(fundis.can_edit?(rolf)) # herbarium has no curators
      assert_false(dicks_personal.can_edit?(rolf)) # another user's hebarium

      login("rolf")
      get(:index)

      assert_select("a[href^='#{edit_herbarium_path(nybg)}']", count: 1)
      assert_select("a[href^='#{edit_herbarium_path(fundis)}']", count: 1)
      assert_select("a[href^='#{edit_herbarium_path(dicks_personal)}']",
                    count: 0)
      assert_select("a[href='#{herbaria_path(merge: nybg)}']", count: 1)
      assert_select("a[href='#{herbaria_path(merge: fundis)}']", count: 1)
      assert_select("a[href='#{herbaria_path(merge: dicks_personal)}']",
                    count: 0)
      assert_select("a[href^='herbaria_merge_path']", count: 0)
    end

    def test_index_merge_source_links_presence_dick
      assert_false(nybg.can_edit?(dick)) # not a curator
      assert_true(fundis.can_edit?(dick)) # no curators
      assert_true(dicks_personal.can_edit?(dick)) # user's personal herbarium

      login("dick")
      get(:index)

      assert_select("a[href^='#{edit_herbarium_path(nybg)}']", count: 0)
      assert_select("a[href^='#{edit_herbarium_path(fundis)}']", count: 1)
      assert_select("a[href^='#{edit_herbarium_path(dicks_personal)}']",
                    count: 1)
      assert_select("a[href='#{herbaria_path(merge: nybg)}']", count: 0)
      assert_select("a[href='#{herbaria_path(merge: fundis)}']", count: 1)
      assert_select("a[href='#{herbaria_path(merge: dicks_personal)}']",
                    count: 1)
      assert_select("a[href^='herbaria_merge_path']", count: 0)
    end

    def test_index_merge_source_links_presence_admin
      make_admin("zero")
      get(:index)

      assert_select("a[href^='#{edit_herbarium_path(nybg)}']", count: 1)
      assert_select("a[href^='#{edit_herbarium_path(fundis)}']", count: 1)
      assert_select("a[href^='#{edit_herbarium_path(dicks_personal)}']",
                    count: 1)
      assert_select("a[href='#{herbaria_path(merge: nybg)}']", count: 1)
      assert_select("a[href='#{herbaria_path(merge: fundis)}']", count: 1)
      assert_select("a[href='#{herbaria_path(merge: dicks_personal)}']",
                    count: 1)
      assert_select("a[href^='herbaria_merge_path']", count: 0)
    end

    def test_index_merge_source_links_presence_no_login
      get(:index)
      assert_select("a[href*=edit]", count: 0)
      assert_select("a[href^='herbaria_merge_path']", count: 0)
    end

    def test_index_merge_target_links_presence_rolf
      source = field_museum
      assert_true(nybg.can_edit?(rolf)) # rolf id curator
      assert_true(fundis.can_edit?(rolf)) # no curators
      assert_false(dicks_personal.can_edit?(rolf)) # another user's hebarium

      login("dick")
      get(:index, params: { merge: source.id })
      assert_select("a[href*='this=#{source.id}']", count: 0)
      assert_select("a[href*='this=#{nybg.id}']", count: 1)
      assert_select("a[href*='this=#{fundis.id}']", count: 1)
      assert_select("a[href*='this=#{dicks_personal.id}']", count: 1)

      login("rolf")
      get(:index, params: { merge: source.id })
      assert_select("a[href*='this=#{source.id}']", count: 0)
      assert_select("a[href*='this=#{nybg.id}']", count: 1)
      assert_select("a[href*='this=#{fundis.id}']", count: 1)
      assert_select("a[href*='this=#{dicks_personal.id}']", count: 1)
    end

    def test_index_merge_target_links_presence_dick
      source = field_museum
      assert_false(nybg.can_edit?(dick)) # dick is not a curator
      assert_true(fundis.can_edit?(dick)) # no curators
      assert_true(dicks_personal.can_edit?(dick)) # user's personal herbarium

      login("dick")
      get(:index, params: { merge: source.id })
      assert_select("a[href*='this=#{source.id}']", count: 0)
      assert_select("a[href*='this=#{nybg.id}']", count: 1)
      assert_select("a[href*='this=#{fundis.id}']", count: 1)
      assert_select("a[href*='this=#{dicks_personal.id}']", count: 1)
    end

    def test_index_merge_target_links_presence_admin
      source = field_museum
      make_admin("zero")
      get(:index, params: { merge: source.id })

      assert_select("a[href*='this=#{source.id}']", count: 0)
      assert_select("a[href*='this=#{nybg.id}']", count: 1)
      assert_select("a[href*='this=#{fundis.id}']", count: 1)
      assert_select("a[href*='this=#{dicks_personal.id}']", count: 1)
    end

    def test_index_merge_target_links_presence_no_login
      source = field_museum
      get(:index, params: { merge: source.id })

      assert_select("a[href*=edit]", count: 0)
      assert_select("a[href^='herbaria_merge_path']", count: 0)
    end
  end
end
