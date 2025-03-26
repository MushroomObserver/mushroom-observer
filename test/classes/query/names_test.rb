# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Names class to be included in QueryTest
class Query::NamesTest < UnitTestCase
  include QueryExtensions

  def test_name_all
    # NOTE: misspellings are modified by `do_test_name_all`
    # This saves looking up Name.order_by_default a bunch of times.
    expect = Name.order_by_default
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
    expects = Name.order_by(:rss_log)
    assert_query(expects, :Name, order_by: :rss_log)
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
    set = names_set.map(&:id)
    scope = Name.id_in_set(set)
    assert_query_scope(set, scope, :Name, id_in_set: names_set.map(&:id))
  end

  # `with_correct_spelling` temporarily necessary because scopes don't have
  def test_name_by_users
    users = [mary, dick, rolf]
    users.each do |user|
      expects = Name.where(user:).with_correct_spelling.order_by_default
      scope = Name.by_users(user).with_correct_spelling.order_by_default
      assert_query_scope(expects, scope, :Name, by_users: user)
      scope = Name.by_users(user.login).with_correct_spelling.order_by_default
      assert_query_scope(expects, scope, :Name, by_users: user.login)
    end
    assert_query([], :Name, by_users: users(:zero_user))
  end

  def test_name_by_editor
    assert_query([], :Name, by_editor: rolf)
    assert_query([], :Name, by_editor: mary)
    expects = Name.with_correct_spelling.by_editor(dick).order_by(:id)
    assert_query(expects, :Name, by_editor: dick, order_by: :id)
  end

  def test_name_users_login
    # single
    expects = Name.by_users(users(:rolf).login).order_by_default
    assert_query(expects, :Name, by_users: users(:rolf).login)
    # array
    users = [users(:rolf), users(:mary)].map(&:login)
    expects = Name.by_users(users).order_by_default
    assert_query(expects, :Name, by_users: users)
  end

  def test_name_users_id
    # single
    users = users(:rolf).id
    expects = Name.by_users(users).order_by_default
    assert_query(expects, :Name, by_users: users)
    # array
    users = [users(:rolf), users(:mary)].map(&:id)
    expects = Name.by_users(users).order_by_default
    assert_query(expects, :Name, by_users: users)
  end

  def test_name_users_instance
    # single
    users = users(:rolf)
    expects = Name.by_users(users).order_by_default
    assert_query(expects, :Name, by_users: users)
    # array
    users = [users(:rolf), users(:mary)]
    expects = Name.by_users(users).order_by_default
    assert_query(expects, :Name, by_users: users)
  end

  # Takes region strings or ids, but not instances
  def test_name_locations
    locations = [locations(:salt_point), locations(:gualala)].
                map { |x| x.id.to_s }
    expects = Name.locations(locations).order_by_default
    assert_query(expects, :Name, locations: locations)
    # locations = [locations(:salt_point), locations(:gualala)]
    # assert_query(expects, :Name, locations: locations)

    locations = ["Sonoma Co., California, USA"]
    expects = Name.locations(locations).order_by_default
    assert_query(expects, :Name, locations: locations)
  end

  def test_name_species_lists
    spl = [species_lists(:unknown_species_list).title]
    expects = Name.species_lists(spl).order_by_default
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
    scope = Name.names(lookup: set, include_subtaxa: true).order_by_default
    assert_query_scope(
      expects, scope, :Name, names: { lookup: set, include_subtaxa: true }
    )
  end

  def test_name_names_include_subtaxa_exclude_original
    name = names(:agaricus)
    assert_query(
      Name.names(lookup: name.id,
                 include_subtaxa: true,
                 exclude_original_names: true).order_by_default,
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
      Name.names(lookup: name.id,
                 include_subtaxa: true,
                 exclude_original_names: true).order_by_default,
      :Name, names: { lookup: name.id,
                      include_subtaxa: true,
                      exclude_original_names: true }
    )
  end

  def test_name_names_include_subtaxa_include_original
    assert_query(
      Name.names(lookup: names(:agaricus),
                 include_subtaxa: true,
                 exclude_original_names: false).order_by_default,
      :Name, names: { lookup: [names(:agaricus).id],
                      include_subtaxa: true,
                      exclude_original_names: false }
    )
  end

  def test_name_names_include_immediate_subtaxa
    assert_query(
      Name.names(lookup: names(:agaricus),
                 include_immediate_subtaxa: true,
                 exclude_original_names: false).order_by_default,
      :Name, names: { lookup: [names(:agaricus).id],
                      include_immediate_subtaxa: true,
                      exclude_original_names: false }
    )
  end

  # def test_name_deprecated_only
  #   expects = Name.with_correct_spelling.deprecated.order_by_default
  #   assert_query(expects, :Name, deprecated: :only)
  #   expects = Name.with_correct_spelling.not_deprecated.order_by_default
  #   assert_query(expects, :Name, deprecated: :no)
  #   expects = Name.with_correct_spelling.order_by_default
  #   assert_query(expects, :Name, deprecated: :either)
  # end

  def test_name_deprecated
    expects = Name.with_correct_spelling.deprecated.order_by_default
    assert_query(expects, :Name, deprecated: true)

    trues = [true, "true", 1, "1"]
    trues.each do |val|
      expects = Name.with_correct_spelling.deprecated(val).order_by_default
      assert_query(expects, :Name, deprecated: true)

      expects = Name.with_correct_spelling.deprecated.order_by_default
      assert_query(expects, :Name, deprecated: val)
    end

    falses = [false, "false", 0, "0"]
    falses.each do |val|
      expects = Name.with_correct_spelling.deprecated(val).order_by_default
      assert_query(expects, :Name, deprecated: false)

      expects = Name.with_correct_spelling.deprecated(false).order_by_default
      assert_query(expects, :Name, deprecated: val)
    end
  end

  def test_name_has_synonyms
    expects = Name.with_correct_spelling.has_synonyms.order_by_default
    assert_query(expects, :Name, has_synonyms: true)
    expects = Name.with_correct_spelling.has_synonyms(false).order_by_default
    assert_query(expects, :Name, has_synonyms: false)
  end

  def test_name_rank_single
    expects = Name.with_correct_spelling.rank("Family").order_by_default
    assert_query(expects, :Name, rank: "Family")
  end

  # NOTE: Something is wrong in the fixtures between Genus and Family
  def test_name_rank_range
    expects = Name.with_correct_spelling.rank("Genus", "Kingdom").
              order_by_default
    assert_query(expects, :Name, rank: %w[Genus Kingdom])

    expects = Name.with_correct_spelling.rank("Family").order_by_default
    assert_query(expects, :Name, rank: %w[Family Family])
  end

  def test_name_text_name_has
    expects = Name.with_correct_spelling.
              text_name_has("Agaricus").order_by_default
    assert_query(expects, :Name, text_name_has: "Agaricus")
  end

  def test_name_has_author
    expects = Name.with_correct_spelling.has_author.order_by_default
    assert_query(expects, :Name, has_author: true)
    expects = Name.with_correct_spelling.has_author(false).order_by_default
    assert_query(expects, :Name, has_author: false)
  end

  def test_name_author_has
    expects = Name.with_correct_spelling.author_has("Pers.").order_by_default
    assert_query(expects, :Name, author_has: "Pers.")
  end

  def test_name_has_citation
    expects = Name.with_correct_spelling.has_citation.order_by_default
    assert_query(expects, :Name, has_citation: true)
    expects = Name.with_correct_spelling.has_citation(false).order_by_default
    assert_query(expects, :Name, has_citation: false)
  end

  def test_name_citation_has
    expects = Name.with_correct_spelling.
              citation_has("Lichenes").order_by_default
    assert_query(expects, :Name, citation_has: "Lichenes")
  end

  def test_name_has_classification
    expects = Name.with_correct_spelling.has_classification.order_by_default
    assert_query(expects, :Name, has_classification: true)
    expects = Name.with_correct_spelling.has_classification(false).
              order_by_default
    assert_query(expects, :Name, has_classification: false)
  end

  def test_name_classification_has
    expects = Name.with_correct_spelling.
              classification_has("Tremellales").order_by_default
    assert_query(expects, :Name, classification_has: "Tremellales")
  end

  def test_name_has_notes
    expects = Name.with_correct_spelling.has_notes.order_by_default
    assert_query(expects, :Name, has_notes: true)
    expects = Name.with_correct_spelling.has_notes(false).order_by_default
    assert_query(expects, :Name, has_notes: false)
  end

  def test_name_notes_has
    expects = Name.with_correct_spelling.
              notes_has('"at least one"').order_by_default
    assert_query(expects, :Name, notes_has: '"at least one"')
  end

  def test_name_has_comments_true
    expects = Name.with_correct_spelling.has_comments.order_by_default
    assert_query(expects, :Name, has_comments: true)
  end

  # Note that this is NOT a without comments condition
  def test_name_has_comments_false
    expects = Name.with_correct_spelling.order_by_default
    assert_query(expects, :Name, has_comments: false)
  end

  def test_name_comments_has
    expects = Name.with_correct_spelling.
              comments_has('"messes things up"').order_by_default
    assert_query(expects, :Name, comments_has: '"messes things up"')
  end

  def test_name_pattern_search_search_name
    # search_name
    assert_query([], :Name, pattern: "petigera")
    expects = [names(:petigera).id]
    scope = Name.pattern("petigera").misspellings(:either)
    assert_query_scope(
      expects, scope,
      :Name, pattern: "petigera", misspellings: :either
    )
  end

  def test_name_pattern_search_citation
    expects = [names(:peltigera).id]
    scope = Name.pattern("ye auld manual of lichenes")
    assert_query_scope(
      expects, scope, :Name, pattern: "ye auld manual of lichenes"
    )
  end

  def test_name_pattern_search_description_notes
    expects = [names(:agaricus_campestras).id]
    scope = Name.pattern("prevent me")
    assert_query_scope(
      expects, scope, :Name, pattern: "prevent me"
    )
  end

  def test_name_pattern_search_description_gen_desc
    expects = [names(:suillus).id]
    scope = Name.pattern("smell as sweet")
    assert_query_scope(
      expects, scope, :Name, pattern: "smell as sweet"
    )
  end

  # Prove pattern search gets hits for description look_alikes
  def test_name_pattern_search_description_look_alikes
    expects = [names(:peltigera).id]
    scope = Name.pattern("superficially similar")
    assert_query_scope(
      expects, scope, :Name, pattern: "superficially similar"
    )
  end

  def test_name_advanced_search_name
    assert_query_scope([names(:macrocybe_titans).id],
                       Name.search_name("macrocybe*titans"),
                       :Name, search_name: "macrocybe*titans")
  end

  def test_name_advanced_search_where
    assert_query_scope([names(:coprinus_comatus).id],
                       Name.search_where("glendale"),
                       :Name, search_where: "glendale")
    expects = Name.order_by_default.joins(:observations).
              where(Observation[:location_id].eq(locations(:burbank).id)).
              distinct
    scope = Name.order_by_default.search_where("burbank")
    assert_query_scope(expects, scope, :Name, search_where: "burbank")
  end

  def test_name_advanced_search_user
    expects = Name.order_by_default.joins(:observations).
              where(Observation[:user_id].eq(rolf.id)).distinct
    scope = Name.order_by_default.search_user("rolf")
    assert_query_scope(expects, scope, :Name, search_user: "rolf")
  end

  def test_name_advanced_search_content
    assert_query_scope([names(:coprinus_comatus).id], # notes
                       Name.search_content("second fruiting"),
                       :Name, search_content: "second fruiting")
    assert_query_scope([names(:fungi).id], # comment
                       Name.search_content('"a little of everything"'),
                       :Name, search_content: '"a little of everything"')
  end

  def test_name_needs_description
    expects = Name.with_correct_spelling.needs_description
    assert_query(expects, :Name, needs_description: 1)
  end

  def test_name_has_default_description
    scope = Name.order_by_default.has_default_description
    assert_query(scope, :Name, has_default_description: 1)
  end

  def test_name_has_descriptions
    expects = Name.order_by_default.with_correct_spelling.
              has_descriptions.distinct
    assert_query(expects, :Name, has_descriptions: 1)
  end

  def test_name_with_description_subquery_by_users
    users = [mary, dick]
    users.each do |user|
      expects = Name.with_correct_spelling.joins(:descriptions).distinct.
                where(name_descriptions: { user: user }).order_by_default
      scope = Name.joins(:descriptions).distinct.
              merge(NameDescription.by_users(user)).order_by_default
      assert_query_scope(expects, scope,
                         :Name, description_query: { by_users: user })
    end
  end

  def test_name_with_description_subquery_by_author
    authors = [rolf, mary, dick]
    authors.each do |author|
      expects = Name.with_correct_spelling.
                joins(descriptions: :name_description_authors).distinct.
                where(name_description_authors: { user: author }).
                order_by_default
      scope = Name.joins(:descriptions).distinct.
              merge(NameDescription.by_author(author)).order_by_default
      assert_query_scope(expects, scope,
                         :Name, description_query: { by_author: author })
    end
  end

  def test_name_with_description_subquery_by_editor
    editors = [rolf, mary, dick]
    editors.each do |editor|
      expects = Name.with_correct_spelling.
                joins(descriptions: :name_description_editors).distinct.
                where(name_description_editors: { user: editor }).
                order_by_default
      scope = Name.joins(:descriptions).distinct.
              merge(NameDescription.by_editor(editor)).order_by_default

      assert_equal(0, expects.length) if editor == dick
      assert_query_scope(expects, scope,
                         :Name, description_query: { by_editor: editor })
    end
  end

  def test_name_with_description_subquery_in_set
    desc1 = name_descriptions(:peltigera_desc)
    desc2 = name_descriptions(:peltigera_alt_desc)
    desc3 = name_descriptions(:draft_boletus_edulis)
    name1 = names(:peltigera)
    name2 = names(:boletus_edulis)
    expects = [name2, name1]
    set = [desc1, desc2, desc3].map(&:id)
    scope = Name.joins(:descriptions).distinct.
            merge(NameDescription.id_in_set(set).reorder("")).order_by_default
    assert_query_scope(expects, scope,
                       :Name, description_query: { id_in_set: set })
  end

  def test_name_has_observations
    expects = Name.with_correct_spelling.has_observations.
              select(:name).distinct.pluck(:name_id).sort
    scope = Name.with_correct_spelling.has_observations.order_by(:id)
    assert_query_scope(expects, scope,
                       :Name, has_observations: 1, order_by: :id)
  end

  ##### date/time parameters #####

  def test_name_with_observation_subquery_created_at
    created_at = observations(:california_obs).created_at.as_json[0..9]
    expects = Name.with_correct_spelling.joins(:observations).distinct.
              where(Observation[:created_at] >= created_at).order_by_default
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.created_at(created_at)).order_by_default
    assert_query_scope(expects, scope,
                       :Name, observation_query: { created_at: created_at })
  end

  def test_name_with_observation_subquery_updated_at
    updated_at = observations(:california_obs).updated_at.as_json[0..9]
    expects = Name.with_correct_spelling.joins(:observations).distinct.
              where(Observation[:updated_at] >= updated_at).order_by_default
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.updated_at(updated_at)).order_by_default
    assert_query_scope(expects, scope,
                       :Name, observation_query: { updated_at: updated_at })
  end

  def test_name_with_observation_subquery_date
    date = observations(:california_obs).when.as_json
    expects = Name.with_correct_spelling.joins(:observations).distinct.
              where(Observation[:when] >= date).order_by_default
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.date(date)).order_by_default
    assert_query_scope(expects, scope,
                       :Name, observation_query: { date: date })
  end

  ##### list/string parameters #####

  def test_name_with_observation_subquery_has_notes_fields
    expects = Name.with_correct_spelling.joins(:observations).distinct.
              where(Observation[:notes].matches("%:substrate:%")).
              order_by_default
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.has_notes_fields("substrate")).order_by_default
    assert_query_scope(
      expects, scope,
      :Name, observation_query: { has_notes_fields: "substrate" }
    )
  end

  def test_name_with_observation_subquery_herbaria
    name = "The New York Botanical Garden"
    expects = Name.order_by_default.with_correct_spelling.
              joins(observations: { herbarium_records: :herbarium }).
              where(herbaria: { name: name }).distinct
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.herbaria(name)).order_by_default
    assert_query_scope(expects, scope,
                       :Name, observation_query: { herbaria: name })
  end

  ##### numeric parameters #####

  def test_name_with_observation_subquery_confidence
    expects = Name.with_correct_spelling.joins(:observations).distinct.
              where(observations: { vote_cache: 1..3 }).order_by_default
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.confidence([1, 3])).order_by_default
    assert_query_scope(expects, scope,
                       :Name, observation_query: { confidence: [1, 3] })
  end

  def test_name_with_observation_subquery_in_box
    # north/south/east/west
    obs = observations(:unknown_with_lat_lng)
    lat = obs.lat
    lng = obs.lng
    expects = Name.with_correct_spelling.joins(:observations).distinct.
              where(observations: { lat:, lng: }).order_by_default
    box = { north: lat.to_f, south: lat.to_f,
            west: lng.to_f, east: lng.to_f }
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.in_box(**box)).order_by_default
    assert_query_scope(expects, scope,
                       :Name, observation_query: { in_box: box })
  end

  ##### boolean parameters #####

  def test_name_with_observation_subquery_has_comments
    expects = Name.with_correct_spelling.
              joins(observations: :comments).distinct.order_by_default
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.has_comments).order_by_default
    assert_query_scope(expects, scope,
                       :Name, observation_query: { has_comments: true })
  end

  def test_name_with_observation_subquery_has_public_lat_lng
    expects = Name.with_correct_spelling.joins(:observations).distinct.
              where.not(observations: { lat: false }).order_by_default
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.has_public_lat_lng).order_by_default
    assert_query_scope(
      expects, scope, :Name, observation_query: { has_public_lat_lng: true }
    )
  end

  def test_name_with_observation_subquery_has_name_false
    expects = Name.order_by_default.with_correct_spelling.joins(:observations).
              where(observations: { name_id: Name.unknown }).distinct
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.has_name(false)).order_by_default
    assert_query_scope(
      expects, scope, :Name, observation_query: { has_name: false }
    )
  end

  def test_name_with_observation_subquery_has_notes
    expects = Name.order_by_default.with_correct_spelling.joins(:observations).
              where.not(observations: { notes: Observation.no_notes }).distinct
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.has_notes).order_by_default
    assert_query_scope(
      expects, scope, :Name, observation_query: { has_notes: true }
    )
  end

  def test_name_with_observation_subquery_has_sequences
    expects = Name.order_by_default.with_correct_spelling.
              joins(observations: :sequences).distinct
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.has_sequences).order_by_default
    assert_query_scope(
      expects, scope, :Name, observation_query: { has_sequences: true }
    )
  end

  def test_name_with_observation_subquery_is_collection_location
    expects = Name.order_by_default.with_correct_spelling.joins(:observations).
              where(observations: { is_collection_location: true }).distinct
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.is_collection_location).order_by_default
    assert_query_scope(
      expects, scope, :Name, observation_query: { is_collection_location: true }
    )
  end

  def test_name_with_observation_subquery_locations
    loc = locations(:burbank)
    expects = Name.order_by_default.with_correct_spelling.joins(:observations).
              where(observations: { location: loc }).distinct
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.locations(loc)).order_by_default
    assert_query_scope(
      expects, scope, :Name, observation_query: { locations: loc }
    )
  end

  def test_name_with_observation_subquery_search_where
    expects = [names(:coprinus_comatus).id]
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.search_where("glendale")).order_by_default
    assert_query_scope(
      expects, scope, :Name, observation_query: { search_where: "glendale" }
    )
  end

  def test_name_with_observation_subquery_by_users
    users = [rolf, mary, dick]
    users.each do |user|
      expects = Name.with_correct_spelling.joins(:observations).distinct.
                where(observations: { user: user }).order_by_default
      scope = Name.with_correct_spelling.joins(:observations).distinct.
              merge(Observation.by_users(user)).order_by_default
      assert_query_scope(expects, scope,
                         :Name, observation_query: { by_users: user })
    end
    assert_query([], :Name, observation_query: { by_users: users(:zero_user) })
  end

  def test_name_with_observation_subquery_projects
    projects = [projects(:empty_project),
                projects(:two_img_obs_project),
                projects(:bolete_project)]
    projects.each do |pj|
      expects = pj.observations.map(&:name).uniq
      assert_equal(expects, []) if pj == projects(:empty_project)
      scope = Name.with_correct_spelling.joins(:observations).distinct.
              merge(Observation.projects(pj)).order_by_default
      assert_query_scope(
        expects, scope, :Name, observation_query: { projects: pj }
      )
    end
  end

  def test_name_with_observation_subquery_species_lists
    spl = species_lists(:unknown_species_list)
    expects = Name.order_by_default.with_correct_spelling.
              joins({ observations: :species_list_observations }).
              where(species_list_observations: { species_list: spl }).uniq
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.species_lists(spl)).order_by_default
    assert_query_scope(
      expects, scope, :Name, observation_query: { species_lists: spl }
    )

    spl2 = species_lists(:first_species_list)
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.species_lists(spl2)).order_by_default
    assert_query_scope(
      [], scope, :Name, observation_query: { species_lists: spl2 }
    )
  end

  def three_amigos
    [
      observations(:detailed_unknown_obs).id,
      observations(:agaricus_campestris_obs).id,
      observations(:agaricus_campestras_obs).id
    ].freeze
  end

  def test_name_with_observation_subquery_in_set
    expects = Name.with_correct_spelling.joins(:observations).distinct.
              where(observations: { id: three_amigos }).
              order_by_default
    scope = Name.with_correct_spelling.joins(:observations).distinct.
            merge(Observation.id_in_set(three_amigos).reorder("")).
            order_by_default
    assert_query_scope(
      expects, scope, :Name, observation_query: { id_in_set: three_amigos }
    )
  end
end
