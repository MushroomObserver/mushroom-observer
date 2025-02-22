# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::SpeciesLists class to be included in QueryTest
class Query::SpeciesListsTest < UnitTestCase
  include QueryExtensions

  def test_species_list_all
    expects = SpeciesList.index_order
    assert_query(expects, :SpeciesList)
  end

  def test_species_list_sort_by_user
    expects = SpeciesList.order_by_user.to_a
    assert_query(expects, :SpeciesList, by: :user)
  end

  def test_species_list_sort_by_title
    expects = SpeciesList.order(:title).to_a
    assert_query(expects, :SpeciesList, by: :title)
  end

  def test_species_list_at_location
    expects = SpeciesList.where(location: locations(:burbank)).
              index_order.distinct
    assert_query(expects, :SpeciesList, location: locations(:burbank))
    assert_query(
      [], :SpeciesList, location: locations(:unused_location)
    )
  end

  def test_species_list_at_where
    assert_query([], :SpeciesList, search_where: "nowhere")
    assert_query([species_lists(:where_no_mushrooms_list)],
                 :SpeciesList, search_where: "no mushrooms")
  end

  def test_species_list_by_rss_log
    assert_query(SpeciesList.order_by_rss_log, :SpeciesList, by: :rss_log)
  end

  def test_species_list_by_user
    expects = SpeciesList.where(user: mary).index_order.distinct
    assert_query(expects, :SpeciesList, by_user: mary)
    assert_query([], :SpeciesList, by_user: dick)
  end

  def test_species_list_by_user_sort_by_id
    expects = SpeciesList.where(user: rolf).reorder(id: :asc).uniq
    assert_query(expects, :SpeciesList, by_user: rolf, by: :id)
  end

  def test_species_list_for_project
    assert_query([],
                 :SpeciesList, project: projects(:empty_project))
    assert_query(projects(:bolete_project).species_lists,
                 :SpeciesList, project: projects(:bolete_project))
    assert_query(
      projects(:two_list_project).species_lists,
      :SpeciesList, project: projects(:two_list_project)
    )
  end

  def test_species_list_in_set
    list_set_ids = [species_lists(:first_species_list).id,
                    species_lists(:unknown_species_list).id]
    assert_query(list_set_ids, :SpeciesList, ids: list_set_ids)
  end

  def test_species_list_pattern_search
    assert_query([],
                 :SpeciesList, pattern: "nonexistent pattern")
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
    SpeciesList.index_order.left_outer_joins(:location).
      where(SpeciesList[:title].matches("%#{pattern}%").
            or(SpeciesList[:notes].matches("%#{pattern}%")).
            or(SpeciesList[:where].matches("%#{pattern}%")).
            or(Location[:name].matches("%#{pattern}%"))).distinct
  end
end
