# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::SpeciesLists class to be included in QueryTest
class Query::SpeciesListsTest < UnitTestCase
  include QueryExtensions

  def test_species_list_all
    ids = SpeciesList.index_order
    assert_query(ids, :SpeciesList)
  end

  def test_species_list_sort_by_user
    ids = SpeciesList.order_by_user.to_a
    assert_query(ids, :SpeciesList, by: :user)
  end

  def test_species_list_sort_by_title
    ids = SpeciesList.order(:title).to_a
    assert_query(ids, :SpeciesList, by: :title)
  end

  def test_species_list_by_rss_log
    assert_query(SpeciesList.order_by_rss_log, :SpeciesList, by: :rss_log)
  end

  def test_species_list_by_users
    ids = SpeciesList.by_users(mary).index_order
    assert_query(ids, :SpeciesList, by_users: mary)
    assert_query([], :SpeciesList, by_users: dick)
  end

  def test_species_list_by_user_sort_by_id
    ids = SpeciesList.where(user: rolf).reorder(id: :asc).uniq
    assert_query(ids, :SpeciesList, by_users: rolf, by: :id)
  end

  def test_species_list_locations
    scope = SpeciesList.locations(locations(:burbank)).index_order
    assert_query(scope, :SpeciesList, locations: locations(:burbank))
    assert_query(
      [], :SpeciesList, locations: locations(:unused_location)
    )
  end

  def test_species_list_for_projects
    assert_query([],
                 :SpeciesList, projects: projects(:empty_project))
    ids = projects(:bolete_project).species_lists
    scope = SpeciesList.projects(projects(:bolete_project)).index_order
    assert_query_scope(ids, scope,
                       :SpeciesList, projects: projects(:bolete_project))
    ids = projects(:two_list_project).species_lists
    scope = SpeciesList.projects(projects(:two_list_project)).index_order
    assert_query_scope(ids, scope,
                       :SpeciesList, projects: projects(:two_list_project))
  end

  def test_species_list_id_in_set
    ids = [species_lists(:first_species_list).id,
           species_lists(:unknown_species_list).id]
    scope = SpeciesList.id_in_set(ids).index_order
    assert_query_scope(ids, scope, :SpeciesList, id_in_set: ids)
  end

  def test_species_list_title_has
    ids = [species_lists(:first_species_list).id,
           species_lists(:another_species_list).id]
    scope = SpeciesList.title_has("A Species List").index_order
    assert_query_scope(ids, scope, :SpeciesList, title_has: "A Species List")
  end

  def test_species_list_has_notes
    scope = SpeciesList.has_notes.index_order
    assert_query(scope, :SpeciesList, has_notes: true)
  end

  def test_species_list_notes_has
    ids = [species_lists(:first_species_list).id,
           species_lists(:another_species_list).id]
    scope = SpeciesList.notes_has("Skunked").index_order
    assert_query_scope(ids, scope, :SpeciesList, notes_has: "Skunked")
  end

  def test_species_list_search_where
    ids = [species_lists(:where_no_mushrooms_list).id]
    scope = SpeciesList.search_where("No Mushrooms").index_order
    assert_query_scope(ids, scope, :SpeciesList, search_where: "No Mushrooms")
  end

  def test_species_list_pattern
    assert_query([], :SpeciesList, pattern: "nonexistent pattern")
    # in title
    pattern = "query_first_list"
    expects = species_list_pattern_search(pattern)
    assert_query(expects, :SpeciesList, pattern: "query_first_list")
    # in notes
    pattern = species_lists(:query_notes_list).notes
    expects = species_list_pattern_search(pattern)
    assert_query(expects, :SpeciesList, pattern: pattern)
    # in location
    pattern = locations(:burbank).name
    expects = species_list_pattern_search(pattern)
    assert_query(expects, :SpeciesList, pattern: locations(:burbank).name)
    # in where
    pattern = species_lists(:where_list).where
    expects = species_list_pattern_search(pattern)
    assert_query(expects, :SpeciesList, pattern: pattern)

    expects = SpeciesList.index_order
    assert_query(expects, :SpeciesList, pattern: "")
  end

  def species_list_pattern_search(pattern)
    SpeciesList.pattern(pattern).index_order
  end
end
