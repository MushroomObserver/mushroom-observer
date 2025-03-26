# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Locations class to be included in QueryTest
class Query::LocationsTest < UnitTestCase
  include QueryExtensions

  def test_location_all
    expects = Location.order_by_default
    assert_query(expects, :Location)
    expects = Location.reorder(id: :asc)
    assert_query(expects, :Location, order_by: :id)
  end

  def test_location_by_users
    assert_query(Location.reorder(id: :asc).by_users(rolf).distinct,
                 :Location, by_users: rolf, order_by: :id)
    assert_query([], :Location, by_users: users(:zero_user))
  end

  def test_location_by_editor
    assert_query([], :Location, by_editor: rolf)
    User.current = mary
    loc = Location.where.not(user: mary).order_by_default.first
    loc.display_name = "new name"
    loc.save
    assert_query_scope([loc], Location.by_editor(mary),
                       :Location, by_editor: mary)
    assert_query([], :Location, by_editor: dick)
  end

  def test_location_by_rss_log
    expects = Location.order_by_rss_log
    assert_query(expects.to_a, :Location, order_by: :rss_log)
  end

  def location_set
    [
      locations(:gualala).id,
      locations(:albion).id,
      locations(:burbank).id,
      locations(:elgin_co).id
    ].freeze
  end

  def test_location_in_set
    scope = Location.id_in_set(location_set)
    assert_query_scope(location_set, scope, :Location, id_in_set: location_set)
  end

  def test_location_has_notes
    expects = Location.order_by_default.has_notes
    assert_query(expects, :Location, has_notes: true)
    expects = Location.order_by_default.has_notes(false)
    assert_query(expects, :Location, has_notes: false)
  end

  def test_location_notes_has
    expects = [locations(:burbank)]
    scope = Location.order_by_default.notes_has('"should persist"')
    assert_query_scope(expects, scope, :Location, notes_has: '"should persist"')
    expects = [locations(:point_reyes)]
    scope = Location.order_by_default.
            notes_has('"legal to collect" -"Salt Point"')
    assert_query_scope(expects, scope,
                       :Location, notes_has: '"legal to collect" -"Salt Point"')
  end

  def test_location_in_box
    expects = [locations(:burbank)]
    box = { north: 35, south: 34, east: -118, west: -119 }
    scope = Location.order_by_default.in_box(**box)
    assert_query_scope(expects, scope, :Location, in_box: box)
  end

  def test_location_pattern_search
    expects = Location.reorder(id: :asc).pattern("California")
    assert_query(expects, :Location, pattern: "California", order_by: :id)
    assert_query_scope([locations(:elgin_co).id], Location.pattern("Canada"),
                       :Location, pattern: "Canada")
    assert_query([], :Location, pattern: "Canada -Elgin")
  end

  def test_location_advanced_search_name
    assert_query_scope([locations(:burbank).id],
                       Location.search_name("agaricus"),
                       :Location, search_name: "agaricus")
    assert_query([], :Location, search_name: "coprinus")
  end

  def test_location_advanced_search_where
    assert_query_scope([locations(:burbank).id],
                       Location.search_where("burbank"),
                       :Location, search_where: "burbank")
    assert_query_scope([locations(:howarth_park).id,
                        locations(:salt_point).id],
                       Location.search_where("park"),
                       :Location, search_where: "park")
  end

  def test_location_advanced_search_user
    expects = Location.order_by_default.joins(observations: :user).
              where(observations: { user: rolf }).distinct
    scope = Location.order_by_default.search_user("rolf")
    assert_query_scope(expects, scope, :Location, search_user: "rolf")

    expects = Location.order_by_default.joins(observations: :user).
              where(observations: { user: dick }).distinct
    scope = Location.order_by_default.search_user("dick")
    assert_query_scope(expects, scope, :Location, search_user: "dick")
  end

  # content in obs.notes
  def test_location_advanced_search_content_obs_notes
    assert_query(Location.search_content('"strange place"'),
                 :Location, search_content: '"strange place"')
  end

  # content in Obs Comment
  def test_location_advanced_search_content_obs_comments
    assert_query(
      Location.search_content('"a little of everything"'),
      :Location, search_content: '"a little of everything"'
    )
  end

  def test_location_advanced_search_content_location_notes
    assert_query([],
                 :Location, search_content: '"legal to collect"')
  end

  def test_location_advanced_search_content_combos
    assert_query([locations(:burbank).id],
                 :Location, search_name: "agaricus", search_content: '"lawn"')
    assert_query([],
                 :Location, search_name: "agaricus",
                            search_content: '"play with"')
    # from observation and comment for same observation
    assert_query([locations(:burbank).id],
                 :Location,
                 search_content: '"a little of everything" "strange place"')
    # from different comments, should fail
    assert_query([],
                 :Location,
                 search_content: '"minimal unknown" "complicated"')
  end

  def test_location_regexp_search
    expects = Location.regexp("California").order_by_default.distinct
    assert_query(expects, :Location, regexp: ".alifornia")
  end

  def test_location_has_descriptions
    expects = Location.joins(:descriptions).order_by_default.distinct
    assert_query(expects, :Location, has_descriptions: 1)
  end

  def test_location_has_descriptions_by_user
    expects = Location.joins(:descriptions).
              where(descriptions: { user: rolf }).order_by_default.distinct
    assert_query(expects, :Location, description_query: { by_users: rolf })

    assert_query([], :Location, description_query: { by_users: mary })
  end

  def test_location_has_descriptions_by_author
    expects = Location.joins(descriptions: :location_description_authors).
              where(location_description_authors: { user: rolf }).
              order_by_default.distinct
    assert_query(expects, :Location, description_query: { by_author: rolf })
    assert_query([], :Location, description_query: { by_author: mary })
  end

  def test_location_has_descriptions_by_editor
    User.current = mary
    desc = location_descriptions(:albion_desc)
    desc.notes = "blah blah blah"
    desc.save
    assert_query([], :Location, description_query: { by_editor: rolf })

    expects = Location.joins(descriptions: :location_description_editors).
              where(location_description_editors: { user: mary }).
              order_by_default.distinct
    assert_query(expects, :Location, description_query: { by_editor: mary })
  end

  def test_location_has_descriptions_in_set
    ids = [location_descriptions(:albion_desc).id,
           location_descriptions(:no_mushrooms_location_desc).id]
    assert_query(
      [locations(:albion), locations(:no_mushrooms_location)],
      :Location, description_query: { id_in_set: ids }
    )
    ids = [location_descriptions(:albion_desc).id, rolf.id]
    assert_query([locations(:albion)], :Location,
                 description_query: { id_in_set: ids })
    assert_query([],
                 :Location, description_query: { id_in_set: [rolf.id] })
  end

  def test_location_has_observations
    expects = Location.has_observations.order_by_default.distinct
    assert_query(expects, :Location, has_observations: 1)
  end

  # Prove that :has_observations param of Location Query works with each
  # parameter P for which (a) there's no other test of P for
  # Location, OR (b) P behaves differently in :has_observations than in
  # all other params of Location Query's.

  ##### date/time parameters #####

  def test_location_with_observations_created_at
    created_at = observations(:california_obs).created_at
    expects = Location.order_by_default.joins(:observations).
              where(Observation[:created_at] >= created_at).distinct
    assert_query(expects, :Location, observation_query: { created_at: })
  end

  def test_location_with_observations_updated_at
    updated_at = observations(:california_obs).updated_at
    expects = Location.order_by_default.joins(:observations).
              where(Observation[:updated_at] >= updated_at).distinct
    assert_query(expects, :Location, observation_query: { updated_at: })
  end

  def test_location_with_observations_date
    date = observations(:california_obs).when
    expects = Location.order_by_default.joins(:observations).
              where(Observation[:when] >= date).distinct
    assert_query(expects, :Location, observation_query: { date: })
  end

  ##### list/string parameters #####

  def test_location_with_observations_comments_has
    # Create a Comment, unfortunately hitting the db because
    # (a) the query should find multiple Locations;
    # (b) all Observation fixtures with Comments have the same Location; and
    # (c) adding a Comment fixture breaks the tests.
    Comment.create(
      user: katrina,
      summary: "Another cool obs",
      comment: "with different location than minimal_unknown_obs",
      target_type: Observation,
      target: observations(:vouchered_obs)
    )
    assert_query(
      Location.order_by_default.joins(observations: :comments).
               where(Comment[:summary].matches("%cool%")).
               or(
                 Location.order_by_default.joins(observations: :comments).
                          where(Comment[:comment].matches("%cool%"))
               ).distinct,
      :Location, observation_query: { comments_has: "cool" }
    )
  end

  def test_location_with_observations_has_notes_fields
    assert_query(
      Location.order_by_default.joins(:observations).
               where(Observation[:notes].matches("%:substrate:%")).distinct,
      :Location, observation_query: { has_notes_fields: "substrate" }
    )
  end

  def test_location_with_observations_herbaria
    name = "The New York Botanical Garden"
    expects = Location.joins(observations: { herbarium_records: :herbarium }).
              where(herbaria: { name: name }).order_by_default.distinct
    assert_query(expects, :Location, observation_query: { herbaria: name })
  end

  def test_location_with_observations_notes_has
    expects = Location.order_by_default.joins(:observations).
              where(Observation[:notes].matches("%somewhere%")).distinct
    assert_query(
      expects, :Location, observation_query: { notes_has: "somewhere" }
    )
  end

  def test_location_with_observations_locations
    loc_with_observations = locations(:burbank)
    loc_without_observations = locations(:no_mushrooms_location)
    locations = [loc_with_observations, loc_without_observations]
    assert_query(
      [loc_with_observations],
      :Location, observation_query: { locations: locations.map(&:name) }
    )
  end

  def test_location_with_observations_projects
    project = projects(:bolete_project)
    assert_query(
      Location.order_by_default.joins(observations: :projects).
               where(projects: { title: project.title }).distinct,
      :Location, observation_query: { projects: project.title }
    )
  end

  def test_location_with_observations_names
    names = [names(:boletus_edulis), names(:agaricus_campestris)].
            map(&:text_name)
    expects = Location.joins(observations: :name).
              where(observations: { text_name: names }).
              order_by_default.distinct
    assert_query(
      expects, :Location, observation_query: { names: { lookup: names } }
    )
  end

  def test_location_with_observations_include_subtaxa
    parent = names(:agaricus)
    children = Name.order_by_default.
               where(Name[:text_name].matches_regexp(parent.text_name))
    assert_query(
      Location.joins(:observations).
               where(observations: { name: [parent] + children }).distinct,
      :Location, observation_query: {
        names: { lookup: parent.text_name, include_subtaxa: true }
      }
    )
  end

  def test_location_with_observations_include_synonyms
    # Create Observations of synonyms, unfortunately hitting the db, because:
    # (a) there are no Observation fixtures for a Name with a synonym_names; and
    # (b) tests are brittle, so adding an Observation fixture will break them.
    Observation.create(
      location: locations(:albion),
      name: names(:macrolepiota_rachodes),
      user: rolf
    )
    Observation.create(
      location: locations(:howarth_park),
      name: names(:macrolepiota_rhacodes),
      user: rolf
    )
    assert_query(
      [locations(:albion), locations(:howarth_park)],
      :Location, observation_query: {
        names: { lookup: "Macrolepiota rachodes", include_synonyms: true }
      }
    )
  end

  def test_location_with_observations_of_children
    nam = [names(:agaricus).id]
    assert_query(
      [locations(:burbank).id],
      :Location, observation_query: {
        names: { lookup: nam, include_subtaxa: true }
      }
    )
  end

  def test_location_with_observations_of_name
    assert_query(
      [locations(:burbank).id],
      :Location, observation_query: {
        names: { lookup: [names(:agaricus_campestris).id] }
      }
    )
    assert_query(
      [],
      :Location, observation_query: {
        names: { lookup: [names(:peltigera).id] }
      }
    )
  end

  def test_location_with_observations_users
    assert_query(
      Location.order_by_default.joins(:observations).
      where(observations: { user: dick }).distinct,
      :Location, observation_query: { by_users: dick }
    )
  end

  ##### numeric parameters #####

  def test_location_with_observations_confidence
    # Create Observations with both vote_cache and location, because:
    # (a) there aren't Observation fixtures like that, and
    # (b) tests are brittle, so adding or modifying a fixture will break them.
    obses = Observation.order_by_default.where(vote_cache: 1..3)
    obses.each { |obs| obs.update!(location: locations(:albion)) }
    expects = Location.order_by_default.joins(:observations).
              where(observations: { vote_cache: 1..3 }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects,
                 :Location, observation_query: { confidence: [1.0, 3.0] })
  end

  ##### boolean parameters #####
  def test_location_with_observations_has_comments
    assert_query(
      Location.order_by_default.joins(observations: :comments).distinct,
      :Location, observation_query: { has_comments: true }
    )
  end

  def test_location_with_observations_has_public_lat_lng
    assert_query(
      Location.joins(:observations).where(observations: { gps_hidden: false }).
               where.not(observations: { lat: false }).
               order_by_default.distinct,
      :Location, observation_query: { has_public_lat_lng: true }
    )
  end

  def test_location_with_observations_has_name
    expects = Location.order_by_default.joins(:observations).
              where(observations: { name: Name.unknown }).distinct
    assert_query(expects, :Location, observation_query: { has_name: false })
  end

  def test_location_with_observations_has_notes
    expects = Location.order_by_default.joins(:observations).
              where.not(observations: { notes: Observation.no_notes }).distinct
    assert_query(expects, :Location, observation_query: { has_notes: true })
  end

  def test_location_with_observations_has_sequences
    expects = Location.order_by_default.joins(observations: :sequences).distinct
    assert_query(expects,
                 :Location, observation_query: { has_sequences: true })
  end

  def test_location_with_observations_is_collection_location
    expects = Location.order_by_default.joins(:observations).
              where(observations: { is_collection_location: true }).distinct
    assert_query(
      expects, :Location, observation_query: { is_collection_location: true }
    )
  end

  def test_location_with_observations_by_user
    expects = location_with_observations_by_user(rolf)
    assert_query(expects, :Location, observation_query: { by_users: rolf.id })

    zero_user = users(:zero_user)
    expects = location_with_observations_by_user(zero_user)
    assert_equal(0, expects.length)
    assert_query(expects, :Location, observation_query: { by_users: zero_user })
  end

  def location_with_observations_by_user(user)
    Location.joins(:observations).where(observations: { user: user }).
      order_by_default.distinct
  end

  def test_location_with_observations_for_project_empty
    empty = projects(:empty_project)
    assert_query([], :Location, observation_query: { projects: empty })
  end

  # NOTE: is_collection_location: true is automatically added by the related
  # query links for observations for proj/spl. Other callers must add manually.
  def test_location_with_observations_for_project
    pj = projects(:obs_collected_and_displayed_project)
    assert_query([observations(:collected_at_obs).location],
                 :Location, observation_query: { projects: pj,
                                                 is_collection_location: 1 })
  end

  def test_location_with_observations_in_set
    ids = [observations(:minimal_unknown_obs).id]
    assert_query([locations(:burbank).id],
                 :Location, observation_query: { id_in_set: ids })
    ids = [observations(:coprinus_comatus_obs).id]
    assert_query([], :Location, observation_query: { id_in_set: ids })
  end

  def test_location_with_observations_in_species_list
    spl = species_lists(:unknown_species_list).id
    assert_query([locations(:burbank).id],
                 :Location, observation_query: { species_lists: spl,
                                                 is_collection_location: 1 })
    empty = species_lists(:first_species_list).id
    assert_query([], :Location, observation_query: { species_lists: empty })
  end
end
