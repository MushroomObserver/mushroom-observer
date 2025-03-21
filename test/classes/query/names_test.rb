# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Names class to be included in QueryTest
class Query::NamesTest < UnitTestCase
  include QueryExtensions

  def test_name_all
    # NOTE: misspellings are modified by `do_test_name_all`
    # This saves looking up Name.index_order a bunch of times.
    expect = Name.index_order
    expects = expect.to_a
    # SQL does not sort 'Kuhner' and 'Kühner'
    do_test_name_all(expect) if sql_collates_accents?

    pair = expects.select { |x| x.text_name == "Agrocybe arvalis" }
    a = expects.index(pair.first)
    b = expects.index(pair.last)
    expects[a], expects[b] = expects[b], expects[a]
    do_test_name_all(expect)
  end

  def do_test_name_all(expect)
    expect_good = expect.with_correct_spelling
    expect_bad  = expect.with_incorrect_spelling
    assert_query(expect_good.to_a, :Name)
    assert_query(expect.to_a, :Name, misspellings: :either)
    assert_query(expect_good.to_a, :Name, misspellings: :no)
    assert_query(expect_bad.to_a, :Name, misspellings: :only)
  end

  def test_name_by_rss_log
    expects = Name.order_by_rss_log
    assert_query(expects, :Name, by: :rss_log)
  end

  def names_set
    [
      names(:fungi),
      names(:coprinus_comatus),
      names(:conocybe_filaris),
      names(:lepiota_rhacodes),
      names(:lactarius_subalpinus)
    ].freeze
  end

  def test_name_ids_with_name_ids
    assert_query(names_set.map(&:id), :Name, id_in_set: names_set.map(&:id))
  end

  def test_name_ids_with_name_instances
    assert_query(names_set.map(&:id), :Name, id_in_set: names_set)
  end

  def test_name_by_user
    assert_query(Name.index_order.where(user: mary).with_correct_spelling,
                 :Name, by_users: mary)
    assert_query(Name.index_order.where(user: mary).with_correct_spelling,
                 :Name, by_users: "mary")
    assert_query(Name.index_order.where(user: dick).with_correct_spelling,
                 :Name, by_users: dick)
    assert_query(Name.index_order.where(user: rolf).with_correct_spelling,
                 :Name, by_users: rolf)
    assert_query([], :Name, by_users: users(:zero_user))
  end

  def test_name_by_editor
    assert_query([], :Name, by_editor: rolf)
    assert_query([], :Name, by_editor: mary)
    expects = Name.reorder(id: :asc).
              with_correct_spelling.by_editor(dick).distinct
    assert_query(expects, :Name, by_editor: dick, by: :id)
  end

  def test_name_users_login
    # single
    expects = Name.where(user: users(:rolf)).index_order
    assert_query(expects, :Name, by_users: users(:rolf).login)
    # array
    users = [users(:rolf), users(:mary)]
    expects = Name.where(user: users).index_order
    assert_query(expects, :Name, by_users: users.map(&:login))
  end

  def test_name_users_id
    # single
    users = users(:rolf).id
    expects = Name.where(user: users).index_order
    assert_query(expects, :Name, by_users: users)
    # array
    users = [users(:rolf), users(:mary)].map(&:id)
    expects = Name.where(user: users).index_order
    assert_query(expects, :Name, by_users: users)
  end

  def test_name_users_instance
    # single
    users = users(:rolf)
    expects = Name.where(user: users).index_order
    assert_query(expects, :Name, by_users: users)
    # array
    users = [users(:rolf), users(:mary)]
    expects = Name.where(user: users).index_order
    assert_query(expects, :Name, by_users: users)
  end

  # Takes region strings or ids, but not instances
  def test_name_locations
    locations = [locations(:salt_point), locations(:gualala)].
                map { |x| x.id.to_s }
    expects = Name.locations(locations).index_order
    assert_query(expects, :Name, locations: locations)
    # locations = [locations(:salt_point), locations(:gualala)]
    # assert_query(expects, :Name, locations: locations)

    locations = ["Sonoma Co., California, USA"]
    expects = Name.locations(locations).index_order
    assert_query(expects, :Name, locations: locations)
  end

  def test_name_species_lists
    spl = [species_lists(:unknown_species_list).title]
    expects = Name.species_lists(spl).index_order
    assert_query(expects, :Name, species_lists: spl)
  end

  def test_name_names_names
    set = [names(:agaricus), names(:coprinus_comatus),
           names(:macrocybe_titans)]
    expects = [
      names(:agaricus),
      names(:sect_agaricus),
      names(:agaricus_campestras),
      names(:agaricus_campestris),
      names(:agaricus_campestros),
      names(:agaricus_campestrus),
      names(:coprinus_comatus),
      names(:macrocybe_titans)
    ]
    scope = Name.names(lookup: set, include_subtaxa: true).index_order
    assert_query_scope(
      expects, scope, :Name, names: { lookup: set, include_subtaxa: true }
    )
  end

  def test_name_names_include_subtaxa_exclude_original
    name = names(:agaricus)
    assert_query(
      Name.index_order.names(lookup: name.id,
                             include_subtaxa: true,
                             exclude_original_names: true),
      :Name, names: { lookup: [name.id],
                      include_subtaxa: true,
                      exclude_original_names: true }
    )
  end

  # This test ensures we force empty results when the lookup gets no ids.
  def test_name_of_subtaxa_excluding_original_no_children
    name = names(:tubaria_furfuracea)
    assert_query_scope(
      [],
      Name.index_order.names(lookup: name.id,
                             include_subtaxa: true,
                             exclude_original_names: true),
      :Name, names: { lookup: name.id,
                      include_subtaxa: true,
                      exclude_original_names: true }
    )
  end

  def test_name_names_include_subtaxa_include_original
    assert_query(
      Name.index_order.names(lookup: names(:agaricus),
                             include_subtaxa: true,
                             exclude_original_names: false),
      :Name, names: { lookup: [names(:agaricus).id],
                      include_subtaxa: true,
                      exclude_original_names: false }
    )
  end

  def test_name_names_include_immediate_subtaxa
    assert_query(
      Name.index_order.names(lookup: names(:agaricus),
                             include_immediate_subtaxa: true,
                             exclude_original_names: false),
      :Name, names: { lookup: [names(:agaricus).id],
                      include_immediate_subtaxa: true,
                      exclude_original_names: false }
    )
  end

  # def test_name_deprecated_only
  #   expects = Name.with_correct_spelling.deprecated.index_order
  #   assert_query(expects, :Name, deprecated: :only)
  #   expects = Name.with_correct_spelling.not_deprecated.index_order
  #   assert_query(expects, :Name, deprecated: :no)
  #   expects = Name.with_correct_spelling.index_order
  #   assert_query(expects, :Name, deprecated: :either)
  # end

  def test_name_deprecated
    expects = Name.with_correct_spelling.deprecated.index_order
    assert_query(expects, :Name, deprecated: true)

    trues = [true, "true", 1, "1"]
    trues.each do |val|
      expects = Name.with_correct_spelling.deprecated(val).index_order
      assert_query(expects, :Name, deprecated: true)

      expects = Name.with_correct_spelling.deprecated.index_order
      assert_query(expects, :Name, deprecated: val)
    end

    falses = [false, "false", 0, "0"]
    falses.each do |val|
      expects = Name.with_correct_spelling.deprecated(val).index_order
      assert_query(expects, :Name, deprecated: false)

      expects = Name.with_correct_spelling.deprecated(false).index_order
      assert_query(expects, :Name, deprecated: val)
    end
  end

  def test_name_has_synonyms
    expects = Name.with_correct_spelling.has_synonyms.index_order
    assert_query(expects, :Name, has_synonyms: true)
    expects = Name.with_correct_spelling.has_synonyms(false).index_order
    assert_query(expects, :Name, has_synonyms: false)
  end

  def test_name_rank_single
    expects = Name.with_correct_spelling.rank("Family").index_order
    assert_query(expects, :Name, rank: "Family")
  end

  # NOTE: Something is wrong in the fixtures between Genus and Family
  def test_name_rank_range
    expects = Name.with_correct_spelling.rank("Genus", "Kingdom").index_order
    assert_query(expects, :Name, rank: %w[Genus Kingdom])

    expects = Name.with_correct_spelling.rank("Family").index_order
    assert_query(expects, :Name, rank: %w[Family Family])
  end

  def test_name_text_name_has
    expects = Name.with_correct_spelling.
              text_name_has("Agaricus").index_order
    assert_query(expects, :Name, text_name_has: "Agaricus")
  end

  def test_name_has_author
    expects = Name.with_correct_spelling.has_author.index_order
    assert_query(expects, :Name, has_author: true)
    expects = Name.with_correct_spelling.has_author(false).index_order
    assert_query(expects, :Name, has_author: false)
  end

  def test_name_author_has
    expects = Name.with_correct_spelling.author_has("Pers.").index_order
    assert_query(expects, :Name, author_has: "Pers.")
  end

  def test_name_has_citation
    expects = Name.with_correct_spelling.has_citation.index_order
    assert_query(expects, :Name, has_citation: true)
    expects = Name.with_correct_spelling.has_citation(false).index_order
    assert_query(expects, :Name, has_citation: false)
  end

  def test_name_citation_has
    expects = Name.with_correct_spelling.
              citation_has("Lichenes").index_order
    assert_query(expects, :Name, citation_has: "Lichenes")
  end

  def test_name_has_classification
    expects = Name.with_correct_spelling.has_classification.index_order
    assert_query(expects, :Name, has_classification: true)
    expects = Name.with_correct_spelling.has_classification(false).index_order
    assert_query(expects, :Name, has_classification: false)
  end

  def test_name_classification_has
    expects = Name.with_correct_spelling.
              classification_has("Tremellales").index_order
    assert_query(expects, :Name, classification_has: "Tremellales")
  end

  def test_name_has_notes
    expects = Name.with_correct_spelling.has_notes.index_order
    assert_query(expects, :Name, has_notes: true)
    expects = Name.with_correct_spelling.has_notes(false).index_order
    assert_query(expects, :Name, has_notes: false)
  end

  def test_name_notes_has
    expects = Name.with_correct_spelling.
              notes_has('"at least one"').index_order
    assert_query(expects, :Name, notes_has: '"at least one"')
  end

  def test_name_has_comments_true
    expects = Name.with_correct_spelling.has_comments.index_order
    assert_query(expects, :Name, has_comments: true)
  end

  # Note that this is not a withOUT comments condition
  def test_name_has_comments_false
    expects = Name.with_correct_spelling.index_order
    assert_query(expects, :Name, has_comments: false)
  end

  def test_name_comments_has
    expects = Name.with_correct_spelling.
              comments_has('"messes things up"').index_order
    assert_query(expects, :Name, comments_has: '"messes things up"')
  end

  def test_name_pattern_search_search_name
    # search_name
    assert_query([], :Name, pattern: "petigera")
    assert_query([names(:petigera).id],
                 :Name, pattern: "petigera", misspellings: :either)
    assert_query(Name.pattern("petigera").misspellings(:either),
                 :Name, pattern: "petigera", misspellings: :either)
  end

  def test_name_pattern_search_citation
    assert_query([names(:peltigera).id],
                 :Name, pattern: "ye auld manual of lichenes")
    assert_query(Name.pattern("ye auld manual of lichenes"),
                 :Name, pattern: "ye auld manual of lichenes")
  end

  def test_name_pattern_search_description_notes
    assert_query([names(:agaricus_campestras).id],
                 :Name, pattern: "prevent me")
    assert_query(Name.pattern("prevent me"),
                 :Name, pattern: "prevent me")
  end

  def test_name_pattern_search_description_gen_desc
    assert_query([names(:suillus)],
                 :Name, pattern: "smell as sweet")
    assert_query(Name.pattern("smell as sweet"),
                 :Name, pattern: "smell as sweet")
  end

  # Prove pattern search gets hits for description look_alikes
  def test_name_pattern_search_description_look_alikes
    assert_query([names(:peltigera).id],
                 :Name, pattern: "superficially similar")
    assert_query(Name.pattern("superficially similar"),
                 :Name, pattern: "superficially similar")
  end

  def test_name_advanced_search
    assert_query([names(:macrocybe_titans).id],
                 :Name, search_name: "macrocybe*titans")
    assert_query([names(:coprinus_comatus).id],
                 :Name, search_where: "glendale") # where
    expects = Name.index_order.joins(:observations).
              where(Observation[:location_id].eq(locations(:burbank).id)).
              distinct
    assert_query(expects, :Name, search_where: "burbank") # location
    expects = Name.index_order.joins(:observations).
              where(Observation[:user_id].eq(rolf.id)).distinct
    assert_query(expects, :Name, search_user: "rolf")
    assert_query([names(:coprinus_comatus).id], :Name,
                 search_content: "second fruiting") # notes
    assert_query([names(:fungi).id], :Name,
                 search_content: '"a little of everything"') # comment
  end

  def test_name_needs_description
    expects = Name.with_correct_spelling.needs_description
    assert_query(expects, :Name, needs_description: 1)
  end

  def test_name_has_default_description
    scope = Name.index_order.has_default_description
    assert_query(scope, :Name, has_default_description: 1)
  end

  def test_name_has_descriptions
    expects = Name.index_order.with_correct_spelling.
              has_descriptions.distinct
    assert_query(expects, :Name, has_descriptions: 1)
  end

  def test_name_has_descriptions_by_user
    expects = name_has_descriptions_by_user(mary)
    assert_query(expects, :Name, description_query: { by_users: mary })

    expects = name_has_descriptions_by_user(dick)
    assert_query(expects, :Name, description_query: { by_users: dick })
  end

  def name_has_descriptions_by_user(user)
    Name.with_correct_spelling.joins(:descriptions).
      where(name_descriptions: { user: user }).index_order.distinct
  end

  def test_name_has_descriptions_by_author
    expects = name_has_descriptions_by_author(rolf)
    assert_query(expects, :Name, description_query: { by_author: rolf })

    expects = name_has_descriptions_by_author(mary)
    assert_query(expects, :Name, description_query: { by_author: mary })

    expects = name_has_descriptions_by_author(dick)
    assert_query(expects, :Name, description_query: { by_author: dick })
  end

  def name_has_descriptions_by_author(user)
    Name.with_correct_spelling.
      joins(descriptions: :name_description_authors).
      where(name_description_authors: { user: user }).index_order.distinct
  end

  def test_name_has_descriptions_by_editor
    expects = name_has_descriptions_by_editor(rolf)
    assert_query(expects, :Name, description_query: { by_editor: rolf })

    expects = name_has_descriptions_by_editor(rolf)
    assert_query(expects, :Name, description_query: { by_editor: mary })

    expects = name_has_descriptions_by_editor(dick)
    assert_equal(0, expects.length)
    assert_query(expects, :Name, description_query: { by_editor: dick })
  end

  def name_has_descriptions_by_editor(user)
    Name.with_correct_spelling.
      joins(descriptions: :name_description_editors).
      where(name_description_editors: { user: user }).index_order.distinct
  end

  def test_name_has_descriptions_in_set
    desc1 = name_descriptions(:peltigera_desc)
    desc2 = name_descriptions(:peltigera_alt_desc)
    desc3 = name_descriptions(:draft_boletus_edulis)
    name1 = names(:peltigera)
    name2 = names(:boletus_edulis)
    assert_query([name2, name1],
                 :Name, description_query: { id_in_set: [desc1, desc2, desc3] })
  end

  def test_name_has_observations
    expects = Name.with_correct_spelling.has_observations.
              select(:name).distinct.pluck(:name_id).sort
    assert_query(expects, :Name, has_observations: 1, by: :id)
  end

  # Prove that :has_observations param of Name Query works with each
  # parameter P for which (a) there's no other test of P for
  # Name, OR (b) P behaves differently in :has_observations than in
  # all other params of Name Query's.

  ##### date/time parameters #####

  def test_name_with_observations_created_at
    created_at = observations(:california_obs).created_at
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(Observation[:created_at] >= created_at).distinct
    assert_query(expects, :Name, observation_query: { created_at: created_at })
  end

  def test_name_with_observations_updated_at
    updated_at = observations(:california_obs).updated_at
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(Observation[:updated_at] >= updated_at).distinct
    assert_query(expects, :Name, observation_query: { updated_at: updated_at })
  end

  def test_name_with_observations_date
    date = observations(:california_obs).when
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(Observation[:when] >= date).distinct
    assert_query(expects, :Name, observation_query: { date: date })
  end

  ##### list/string parameters #####

  def test_name_with_observations_has_notes_fields
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(Observation[:notes].matches("%:substrate:%")).distinct
    assert_query(
      expects, :Name, observation_query: { has_notes_fields: "substrate" }
    )
  end

  def test_name_with_observations_herbaria
    name = "The New York Botanical Garden"
    expects = Name.index_order.with_correct_spelling.
              joins(observations: { herbarium_records: :herbarium }).
              where(herbaria: { name: name }).distinct
    assert_query(expects, :Name, observation_query: { herbaria: name })
  end

  def test_name_with_observations_projects
    project = projects(:bolete_project)
    expects = Name.index_order.with_correct_spelling.
              joins({ observations: :project_observations }).
              where(project_observations: { project: project }).distinct
    # project.observations.map(&:name).uniq
    assert_query(
      expects, :Name, observation_query: { projects: project.title }
    )
  end

  def test_name_with_observations_users
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(observations: { user: dick }).distinct
    assert_query(expects, :Name, observation_query: { by_users: dick })
  end

  ##### numeric parameters #####

  def test_name_with_observations_confidence
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(observations: { vote_cache: 1..3 }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects, :Name, observation_query: { confidence: [1, 3] })
  end

  def test_name_with_observations_in_box
    # north/south/east/west
    obs = observations(:unknown_with_lat_lng)
    lat = obs.lat
    lng = obs.lng
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(observations: { lat: lat, lng: lng }).distinct
    box = { north: lat.to_f, south: lat.to_f,
            west: lat.to_f, east: lat.to_f }
    assert_query(expects, :Name, observation_query: { in_box: box })
  end

  ##### boolean parameters #####

  def test_name_with_observations_has_comments
    expects = Name.index_order.with_correct_spelling.
              joins(observations: :comments).distinct
    assert_query(expects, :Name, observation_query: { has_comments: true })
  end

  def test_name_with_observations_has_public_lat_lng
    expects = Name.index_order.joins(:observations).
              where.not(observations: { lat: false }).distinct
    assert_query(
      expects, :Name, observation_query: { has_public_lat_lng: true }
    )
  end

  def test_name_with_observations_with_name
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(observations: { name_id: Name.unknown }).distinct
    assert_query(expects, :Name, observation_query: { has_name: false })
  end

  def test_name_with_observations_has_notes
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where.not(observations: { notes: Observation.no_notes }).distinct
    assert_query(expects, :Name, observation_query: { has_notes: true })
  end

  def test_name_with_observations_has_sequences
    expects = Name.index_order.with_correct_spelling.
              joins(observations: :sequences).distinct
    assert_query(expects, :Name, observation_query: { has_sequences: true })
  end

  def test_name_with_observations_is_collection_location
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(observations: { is_collection_location: true }).distinct
    assert_query(
      expects, :Name, observation_query: { is_collection_location: true }
    )
  end

  def test_name_with_observations_at_location
    loc = locations(:burbank)
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(observations: { location: loc }).distinct
    assert_query(expects, :Name, observation_query: { locations: loc })
  end

  def test_name_with_observations_at_where
    assert_query([names(:coprinus_comatus).id],
                 :Name, observation_query: { search_where: "glendale" })
  end

  def test_name_with_observations_by_user
    assert_query(name_with_observations_by_user(rolf),
                 :Name, observation_query: { by_users: rolf })
    assert_query(name_with_observations_by_user(mary),
                 :Name, observation_query: { by_users: mary })
    assert_query([], :Name, observation_query: { by_users: users(:zero_user) })
  end

  def name_with_observations_by_user(user)
    Name.index_order.with_correct_spelling.joins(:observations).
      where(observations: { user: user }).distinct
  end

  def test_name_with_observations_for_project
    project = projects(:empty_project)
    assert_query([], :Name, observation_query: { projects: project })

    project2 = projects(:two_img_obs_project)
    expects = Name.index_order.with_correct_spelling.
              joins({ observations: :project_observations }).
              where(project_observations: { project: project2 }).distinct
    assert_query(expects, :Name, observation_query: { projects: project2 })
  end

  def three_amigos
    [
      observations(:detailed_unknown_obs).id,
      observations(:agaricus_campestris_obs).id,
      observations(:agaricus_campestras_obs).id
    ].freeze
  end

  def test_name_with_observations_in_set
    expects = Name.with_correct_spelling.joins(:observations).
              where(observations: { id: three_amigos }).
              index_order.distinct
    assert_query(expects, :Name, observation_query: { id_in_set: three_amigos })
  end

  def test_name_with_observations_in_species_list
    spl = species_lists(:unknown_species_list)
    expects = Name.index_order.with_correct_spelling.
              joins({ observations: :species_list_observations }).
              where(species_list_observations: { species_list: spl }).uniq
    assert_query(expects, :Name, observation_query: { species_lists: spl })

    spl2 = species_lists(:first_species_list)
    assert_query([], :Name, observation_query: { species_lists: spl2 })
  end
end
