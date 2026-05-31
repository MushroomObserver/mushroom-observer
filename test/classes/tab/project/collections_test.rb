# frozen_string_literal: true

require("test_helper")

# Tests for Tab::Project::Banner + AdminSubtabs. Banner's `#tabs`
# order MUST match the pre-conversion view exactly — this is what
# the user sees in the tab strip on every project page. Each
# conditional branch (observations.any? / species_lists.any? /
# is_admin? / has_targets?) is exercised with the order pinned via
# `assert_equal(expected_order, actual.map(&:class))`.
module Tab::Project
  class CollectionsTest < UnitTestCase
    # Bolete project: has observations, has species_lists, dick is
    # admin, mary is a member (not admin). No targets set.
    def test_banner_with_observations_admin_user
      bolete = projects(:bolete_project)
      dick = users(:dick)

      tabs = Tab::Project::Banner.new(project: bolete, user: dick).to_a

      assert_equal(
        [Tab::Project::Summary,
         Tab::Project::Observations,
         Tab::Project::SpeciesLists,
         Tab::Project::Names,
         Tab::Project::Locations,
         Tab::Project::Admin],
        tabs.map(&:class)
      )
    end

    def test_banner_with_observations_non_admin_member
      bolete = projects(:bolete_project)
      mary = users(:mary)

      tabs = Tab::Project::Banner.new(project: bolete, user: mary).to_a

      # mary is a member but NOT an admin → no Admin tab, no Updates
      assert_equal(
        [Tab::Project::Summary,
         Tab::Project::Observations,
         Tab::Project::SpeciesLists,
         Tab::Project::Names,
         Tab::Project::Locations],
        tabs.map(&:class)
      )
    end

    def test_banner_with_observations_anonymous_user
      bolete = projects(:bolete_project)

      tabs = Tab::Project::Banner.new(project: bolete, user: nil).to_a

      # Anonymous → no Admin, no Updates
      assert_equal(
        [Tab::Project::Summary,
         Tab::Project::Observations,
         Tab::Project::SpeciesLists,
         Tab::Project::Names,
         Tab::Project::Locations],
        tabs.map(&:class)
      )
    end

    # empty_project: no observations, no species_lists. mary is admin.
    def test_banner_no_observations_no_species_lists_admin_user
      empty = projects(:empty_project)
      mary = users(:mary)

      tabs = Tab::Project::Banner.new(project: empty, user: mary).to_a

      # Non-observation branch + no species_lists → SpeciesLists omitted.
      # mary is admin → Admin appears. No targets → no Updates.
      assert_equal(
        [Tab::Project::Summary,
         Tab::Project::Names,
         Tab::Project::Locations,
         Tab::Project::Admin],
        tabs.map(&:class)
      )
    end

    # two_list_project: no observations, has species_lists. mary is admin.
    def test_banner_no_observations_with_species_lists
      two_list = projects(:two_list_project)
      mary = users(:mary)

      tabs = Tab::Project::Banner.new(project: two_list, user: mary).to_a

      # Non-observation branch + species_lists.any? → SpeciesLists
      # appears between Summary and Names.
      assert_equal(
        [Tab::Project::Summary,
         Tab::Project::SpeciesLists,
         Tab::Project::Names,
         Tab::Project::Locations,
         Tab::Project::Admin],
        tabs.map(&:class)
      )
    end

    def test_banner_to_internal_links_returns_internal_link_objects
      bolete = projects(:bolete_project)
      links = Tab::Project::Banner.new(project: bolete, user: nil).
              to_internal_links

      assert_predicate(links, :any?)
      links.each { |link| assert_kind_of(InternalLink, link) }
    end

    def test_banner_enumerable_yields_tab_pororos
      bolete = projects(:bolete_project)
      collection = Tab::Project::Banner.new(project: bolete, user: nil)
      collected = collection.map(&:class)

      assert_equal(collection.to_a.map(&:class), collected)
      collection.each { |t| assert_kind_of(Tab::Base, t) }
    end

    # AdminSubtabs: always Details, Members, Aliases in that order.
    def test_admin_subtabs_order
      bolete = projects(:bolete_project)
      tabs = Tab::Project::AdminSubtabs.new(project: bolete).to_a

      assert_equal(
        [Tab::Project::AdminDetails,
         Tab::Project::AdminMembers,
         Tab::Project::AdminAliases],
        tabs.map(&:class)
      )
    end

    # IndexNav: the "Add Project" action-nav collection for the
    # projects index page.
    def test_index_nav_collection
      tabs = Tab::Project::IndexNav.new.to_a

      assert_equal([Tab::Project::New], tabs.map(&:class))
    end

    # FormNew: just a cancel-to-index link.
    def test_form_new_collection
      tabs = Tab::Project::FormNew.new.to_a

      assert_equal([Tab::Project::Index], tabs.map(&:class))
    end
  end
end
