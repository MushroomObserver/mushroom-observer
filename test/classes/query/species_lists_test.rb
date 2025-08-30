# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::SpeciesLists class to be included in QueryTest
class Query::SpeciesListsTest < UnitTestCase
  include QueryExtensions

  def test_species_list_all
    expects = SpeciesList.order_by_default
    assert_query(expects, :SpeciesList)
  end

  def test_species_list_order_by_name
    expects = SpeciesList.order_by(:name)
    assert_query(expects, :SpeciesList, order_by: :name)
  end

  def test_species_list_order_by_reverse_name
    expects = SpeciesList.order_by(:reverse_name)
    assert_query(expects, :SpeciesList, order_by: :reverse_name)
  end

  def test_species_list_order_by_user
    expects = SpeciesList.order_by(:user).to_a
    assert_query(expects, :SpeciesList, order_by: :user)
  end

  def test_species_list_order_by_reverse_user
    expects = SpeciesList.order_by(:reverse_user).to_a
    assert_query(expects, :SpeciesList, order_by: :reverse_user)
  end

  def test_species_list_order_by_title
    expects = SpeciesList.order_by(:title).to_a
    assert_query(expects, :SpeciesList, order_by: :title)
  end

  def test_species_list_order_by_where
    expects = SpeciesList.order_by(:where).to_a
    assert_query(expects, :SpeciesList, order_by: :where)
  end

  def test_species_list_order_by_rss_log
    expects = SpeciesList.order_by(:rss_log).to_a
    assert_query(expects, :SpeciesList, order_by: :rss_log)
  end

  def test_species_list_by_users
    ids = SpeciesList.by_users(mary).order_by_default
    assert_query(ids, :SpeciesList, by_users: mary)
    assert_query([], :SpeciesList, by_users: dick)
  end

  def test_species_list_by_user_order_by_id
    ids = SpeciesList.by_users(rolf).distinct.order_by(:id)
    assert_query(ids, :SpeciesList, by_users: rolf, order_by: :id)
  end

  def test_species_list_locations
    scope = SpeciesList.locations(locations(:burbank)).order_by_default
    assert_query(scope, :SpeciesList, locations: locations(:burbank))
    assert_query(
      [], :SpeciesList, locations: locations(:unused_location)
    )
  end

  def test_species_list_for_projects
    assert_query([],
                 :SpeciesList, projects: projects(:empty_project))
    ids = projects(:bolete_project).species_lists
    scope = SpeciesList.projects(projects(:bolete_project)).order_by_default
    assert_query_scope(ids, scope,
                       :SpeciesList, projects: projects(:bolete_project))
    ids = projects(:two_list_project).species_lists
    scope = SpeciesList.projects(projects(:two_list_project)).order_by_default
    assert_query_scope(ids, scope,
                       :SpeciesList, projects: projects(:two_list_project))
  end

  def test_species_list_id_in_set
    ids = [species_lists(:first_species_list).id,
           species_lists(:unknown_species_list).id]
    scope = SpeciesList.id_in_set(ids).order_by_default
    assert_query_scope(ids, scope, :SpeciesList, id_in_set: ids)
  end

  def test_species_list_title_has
    ids = [species_lists(:another_species_list).id,
           species_lists(:first_species_list).id]
    scope = SpeciesList.title_has("An Observation List").order_by_default
    assert_query_scope(ids, scope, :SpeciesList,
                       title_has: "An Observation List")
  end

  def test_species_list_has_notes
    scope = SpeciesList.has_notes.order_by_default
    assert_query(scope, :SpeciesList, has_notes: true)
  end

  def test_species_list_notes_has
    ids = [species_lists(:another_species_list).id,
           species_lists(:first_species_list).id]
    scope = SpeciesList.notes_has("Skunked").order_by_default
    assert_query_scope(ids, scope, :SpeciesList, notes_has: "Skunked")
  end

  def test_species_list_search_where
    ids = [species_lists(:where_no_mushrooms_list).id]
    scope = SpeciesList.search_where("No Mushrooms").order_by_default
    assert_query_scope(ids, scope, :SpeciesList, search_where: "No Mushrooms")
  end

  def test_species_list_pattern
    assert_query([], :SpeciesList, pattern: "nonexistent pattern")

    # in title
    list = species_lists(:query_first_list)
    assert_pattern_search_query_scope(list, pattern: list.title)

    # in title, with NULL where
    list = species_lists(:no_where_list)
    assert_pattern_search_query_scope(list, pattern: list.title)

    # in notes
    list = species_lists(:query_notes_list)
    assert_pattern_search_query_scope(list, pattern: list.notes)

    # in location
    pattern = locations(:burbank).name
    expects = species_list_pattern_search(pattern)
    assert_query(expects, :SpeciesList, pattern: locations(:burbank).name)

    # in where
    list = species_lists(:where_list)
    assert_pattern_search_query_scope(list, pattern: list.where)

    expects = SpeciesList.order_by_default
    assert_query(expects, :SpeciesList, pattern: "")
  end

  def assert_pattern_search_query_scope(list, pattern:)
    ids = [list.id]
    scope = species_list_pattern_search(pattern)
    assert_query_scope(ids, scope, :SpeciesList, pattern: pattern)
  end

  def species_list_pattern_search(pattern)
    SpeciesList.pattern(pattern).order_by_default
  end
end
