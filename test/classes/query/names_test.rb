# frozen_string_literal: true

require("test_helper")

# tests of Query::Names class to be included in QueryTest
module Query::NamesTest
  def test_name_all
    # NOTE: misspellings are modified by `do_test_name_all`
    # This saves looking up Name.index_order a bunch of times.
    expect = Name.index_order
    expects = expect.to_a
    # SQL does not sort 'Kuhner' and 'Kühner'
    do_test_name_all(expect) if sql_collates_accents?

    pair = expects.select { |x| x.text_name == "Lentinellus ursinus" }
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

  def test_name_in_set
    assert_query([names(:fungi).id,
                  names(:coprinus_comatus).id,
                  names(:conocybe_filaris).id,
                  names(:lepiota_rhacodes).id,
                  names(:lactarius_subalpinus).id],
                 :Name,
                 ids: [names(:fungi).id,
                       names(:coprinus_comatus).id,
                       names(:conocybe_filaris).id,
                       names(:lepiota_rhacodes).id,
                       names(:lactarius_subalpinus).id])
  end

  def test_name_by_user
    assert_query(Name.index_order.where(user: mary).with_correct_spelling,
                 :Name, by_user: mary)
    assert_query(Name.index_order.where(user: dick).with_correct_spelling,
                 :Name, by_user: dick)
    assert_query(Name.index_order.where(user: rolf).with_correct_spelling,
                 :Name, by_user: rolf)
    assert_query([], :Name, by_user: users(:zero_user))
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
    assert_query(expects, :Name, users: users(:rolf).login)
    # array
    users = [users(:rolf), users(:mary)]
    expects = Name.where(user: users).index_order
    assert_query(expects, :Name, users: users.map(&:login))
  end

  def test_name_users_id
    # single
    users = users(:rolf).id
    expects = Name.where(user: users).index_order
    assert_query(expects, :Name, users: users)
    # array
    users = [users(:rolf), users(:mary)].map(&:id)
    expects = Name.where(user: users).index_order
    assert_query(expects, :Name, users: users)
  end

  def test_name_users_instance
    # single
    users = users(:rolf)
    expects = Name.where(user: users).index_order
    assert_query(expects, :Name, users: users)
    # array
    users = [users(:rolf), users(:mary)]
    expects = Name.where(user: users).index_order
    assert_query(expects, :Name, users: users)
  end

  # Takes region strings or ids, but not instances
  def test_name_locations
    locations = [locations(:salt_point), locations(:gualala)].
                map { |x| x.id.to_s }
    expects = Name.at_locations(locations).index_order
    assert_query(expects, :Name, locations: locations)
    # locations = [locations(:salt_point), locations(:gualala)]
    # assert_query(expects, :Name, locations: locations)

    locations = ["Sonoma Co., California, USA"]
    expects = Name.at_locations(locations).index_order
    assert_query(expects, :Name, locations: locations)
  end

  def test_name_species_lists
    spl = [species_lists(:unknown_species_list).title]
    expects = Name.on_species_lists(spl).index_order
    assert_query(expects, :Name, species_lists: spl)
  end

  def test_name_names_include_subtaxa_exclude_original
    assert_query(
      Name.index_order.subtaxa_of(names(:agaricus)),
      :Name, names: [names(:agaricus).id],
             include_subtaxa: true, exclude_original_names: true
    )
  end

  def test_name_names_include_subtaxa_include_original
    assert_query(
      Name.index_order.include_subtaxa_of(names(:agaricus)),
      :Name, names: [names(:agaricus).id],
             include_subtaxa: true, exclude_original_names: false
    )
  end

  def test_name_names_include_immediate_subtaxa
    assert_query(
      Name.index_order.include_immediate_subtaxa_of(names(:agaricus)),
      :Name, names: [names(:agaricus).id],
             include_immediate_subtaxa: true, exclude_original_names: false
    )
  end

  def test_name_deprecated_only
    expects = Name.with_correct_spelling.deprecated.index_order
    assert_query(expects, :Name, deprecated: :only)
    expects = Name.with_correct_spelling.not_deprecated.index_order
    assert_query(expects, :Name, deprecated: :no)
    expects = Name.with_correct_spelling.index_order
    assert_query(expects, :Name, deprecated: :either)
  end

  def test_name_is_deprecated
    expects = Name.with_correct_spelling.deprecated.index_order
    assert_query(expects, :Name, is_deprecated: true)
    expects = Name.with_correct_spelling.not_deprecated.index_order
    assert_query(expects, :Name, is_deprecated: false)
  end

  def test_name_with_synonyms
    expects = Name.with_correct_spelling.with_synonyms.index_order
    assert_query(expects, :Name, with_synonyms: true)
    expects = Name.with_correct_spelling.without_synonyms.index_order
    assert_query(expects, :Name, with_synonyms: false)
  end

  def test_name_rank_single
    expects = Name.with_correct_spelling.with_rank("Family").index_order
    assert_query(expects, :Name, rank: "Family")
  end

  # NOTE: Something is wrong in the fixtures between Genus and Family
  def test_name_rank_range
    expects = Name.with_correct_spelling.
              with_rank_between("Genus", "Kingdom").index_order
    assert_query(expects, :Name, rank: %w[Genus Kingdom])

    expects = Name.with_correct_spelling.with_rank("Family").index_order
    assert_query(expects, :Name, rank: %w[Family Family])
  end

  def test_name_text_name_has
    expects = Name.with_correct_spelling.
              text_name_contains("Agaricus").index_order
    assert_query(expects, :Name, text_name_has: "Agaricus")
  end

  def test_name_with_author
    expects = Name.with_correct_spelling.with_author.index_order
    assert_query(expects, :Name, with_author: true)
    expects = Name.with_correct_spelling.without_author.index_order
    assert_query(expects, :Name, with_author: false)
  end

  def test_name_author_has
    expects = Name.with_correct_spelling.author_contains("Pers.").index_order
    assert_query(expects, :Name, author_has: "Pers.")
  end

  def test_name_with_citation
    expects = Name.with_correct_spelling.with_citation.index_order
    assert_query(expects, :Name, with_citation: true)
    expects = Name.with_correct_spelling.without_citation.index_order
    assert_query(expects, :Name, with_citation: false)
  end

  def test_name_citation_has
    expects = Name.with_correct_spelling.
              citation_contains("Lichenes").index_order
    assert_query(expects, :Name, citation_has: "Lichenes")
  end

  def test_name_with_classification
    expects = Name.with_correct_spelling.with_classification.index_order
    assert_query(expects, :Name, with_classification: true)
    expects = Name.with_correct_spelling.without_classification.index_order
    assert_query(expects, :Name, with_classification: false)
  end

  def test_name_classification_has
    expects = Name.with_correct_spelling.
              classification_contains("Tremellales").index_order
    assert_query(expects, :Name, classification_has: "Tremellales")
  end

  def test_name_with_notes
    expects = Name.with_correct_spelling.with_notes.index_order
    assert_query(expects, :Name, with_notes: true)
    expects = Name.with_correct_spelling.without_notes.index_order
    assert_query(expects, :Name, with_notes: false)
  end

  def test_name_notes_has
    expects = Name.with_correct_spelling.
              notes_contain('"at least one"').index_order
    assert_query(expects, :Name, notes_has: '"at least one"')
  end

  def test_name_with_comments_true
    expects = Name.with_correct_spelling.with_comments.index_order
    assert_query(expects, :Name, with_comments: true)
  end

  # Note that this is not a withOUT comments condition
  def test_name_with_comments_false
    expects = Name.with_correct_spelling.index_order
    assert_query(expects, :Name, with_comments: false)
  end

  def test_name_comments_has
    expects = Name.with_correct_spelling.
              comments_contain('"messes things up"').index_order
    assert_query(expects, :Name, comments_has: '"messes things up"')
  end

  def test_name_pattern_search
    assert_query(
      [],
      :Name, pattern: "petigera" # search_name
    )
    assert_query(
      [names(:petigera).id],
      :Name, pattern: "petigera", misspellings: :either
    )
    assert_query(
      [names(:peltigera).id],
      :Name, pattern: "ye auld manual of lichenes" # citation
    )
    assert_query(
      [names(:agaricus_campestras).id],
      :Name, pattern: "prevent me" # description notes
    )
    assert_query(
      [names(:suillus)],
      :Name, pattern: "smell as sweet" # gen_desc
    )
    # Prove pattern search gets hits for description look_alikes
    assert_query(
      [names(:peltigera).id],
      :Name, pattern: "superficially similar"
    )
  end

  def test_name_advanced_search
    assert_query([names(:macrocybe_titans).id], :Name,
                 name: "macrocybe*titans")
    assert_query([names(:coprinus_comatus).id], :Name,
                 user_where: "glendale") # where
    expects = Name.index_order.joins(:observations).
              where(Observation[:location_id].eq(locations(:burbank).id)).
              distinct
    assert_query(expects, :Name, user_where: "burbank") # location
    expects = Name.index_order.joins(:observations).
              where(Observation[:user_id].eq(rolf.id)).distinct
    assert_query(expects, :Name, user: "rolf")
    assert_query([names(:coprinus_comatus).id], :Name,
                 content: "second fruiting") # notes
    assert_query([names(:fungi).id], :Name,
                 content: '"a little of everything"') # comment
  end

  def test_name_need_description
    expects = Name.with_correct_spelling.index_order.description_needed.distinct
    assert_query(expects, :Name, need_description: 1)
  end

  def test_name_with_descriptions
    expects = Name.index_order.with_correct_spelling.
              joins(:descriptions).distinct
    assert_query(expects, :Name, with_descriptions: 1)
  end

  def test_name_with_descriptions_by_user
    expects = name_with_descriptions_by_user(mary)
    assert_query(expects, :Name, with_descriptions: 1, by_user: mary)

    expects = name_with_descriptions_by_user(dick)
    assert_query(expects, :Name, with_descriptions: 1, by_user: dick)
  end

  def name_with_descriptions_by_user(user)
    Name.with_correct_spelling.joins(:descriptions).
      where(name_descriptions: { user: user }).index_order.distinct
  end

  def test_name_with_descriptions_by_author
    expects = name_with_descriptions_by_author(rolf)
    assert_query(expects, :Name, with_descriptions: 1, by_author: rolf)

    expects = name_with_descriptions_by_author(mary)
    assert_query(expects, :Name, with_descriptions: 1, by_author: mary)

    expects = name_with_descriptions_by_author(dick)
    assert_query(expects, :Name, with_descriptions: 1, by_author: dick)
  end

  def name_with_descriptions_by_author(user)
    Name.with_correct_spelling.
      joins(descriptions: :name_description_authors).
      where(name_description_authors: { user: user }).index_order.distinct
  end

  def test_name_with_descriptions_by_editor
    expects = name_with_descriptions_by_editor(rolf)
    assert_query(expects, :Name, with_descriptions: 1, by_editor: rolf)

    expects = name_with_descriptions_by_editor(rolf)
    assert_query(expects, :Name, with_descriptions: 1, by_editor: mary)

    expects = name_with_descriptions_by_editor(dick)
    assert_equal(0, expects.length)
    assert_query(expects, :Name, with_descriptions: 1, by_editor: dick)
  end

  def name_with_descriptions_by_editor(user)
    Name.with_correct_spelling.
      joins(descriptions: :name_description_editors).
      where(name_description_editors: { user: user }).index_order.distinct
  end

  def test_name_with_descriptions_in_set
    desc1 = name_descriptions(:peltigera_desc)
    desc2 = name_descriptions(:peltigera_alt_desc)
    desc3 = name_descriptions(:draft_boletus_edulis)
    name1 = names(:peltigera)
    name2 = names(:boletus_edulis)
    assert_query([name1, name2],
                 :Name,
                 with_descriptions: 1, desc_ids: [desc1, desc2, desc3])
  end

  def test_name_with_observations
    expects = Name.with_correct_spelling.joins(:observations).
              select(:name).distinct.pluck(:name_id).sort
    assert_query(expects, :Name, with_observations: 1, by: :id)
  end

  # Prove that :with_observations param of Name Query works with each
  # parameter P for which (a) there's no other test of P for
  # Name, OR (b) P behaves differently in :with_observations than in
  # all other params of Name Query's.

  ##### date/time parameters #####

  def test_name_with_observations_created_at
    created_at = observations(:california_obs).created_at
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(Observation[:created_at] >= created_at).distinct
    assert_query(expects, :Name, with_observations: 1, created_at: created_at)
  end

  def test_name_with_observations_updated_at
    updated_at = observations(:california_obs).updated_at
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(Observation[:updated_at] >= updated_at).distinct
    assert_query(expects, :Name, with_observations: 1, updated_at: updated_at)
  end

  def test_name_with_observations_date
    date = observations(:california_obs).when
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(Observation[:when] >= date).distinct
    assert_query(expects, :Name, with_observations: 1, date: date)
  end

  ##### list/string parameters #####

  def test_name_with_observations_with_notes_fields
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(Observation[:notes].matches("%:substrate:%")).distinct
    assert_query(
      expects, :Name, with_observations: 1, with_notes_fields: "substrate"
    )
  end

  def test_name_with_observations_herbaria
    name = "The New York Botanical Garden"
    expects = Name.index_order.with_correct_spelling.
              joins(observations: { herbarium_records: :herbarium }).
              where(herbaria: { name: name }).distinct
    assert_query(expects, :Name, with_observations: 1, herbaria: name)
  end

  def test_name_with_observations_projects
    project = projects(:bolete_project)
    expects = Name.index_order.with_correct_spelling.
              joins({ observations: :project_observations }).
              where(project_observations: { project: project }).distinct
    # project.observations.map(&:name).uniq
    assert_query(expects, :Name, with_observations: 1, projects: project.title)
  end

  def test_name_with_observations_users
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(observations: { user: dick }).distinct
    assert_query(expects, :Name, with_observations: 1, users: dick)
  end

  ##### numeric parameters #####

  def test_name_with_observations_confidence
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(observations: { vote_cache: 1..3 }).distinct
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects, :Name, with_observations: 1, confidence: [1, 3])

    # north/south/east/west
    obs = observations(:unknown_with_lat_lng)
    lat = obs.lat
    lng = obs.lng
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(observations: { lat: lat, lng: lng }).distinct
    assert_query(
      expects,
      :Name,
      with_observations: 1,
      north: lat.to_f, south: lat.to_f, west: lat.to_f, east: lat.to_f
    )
  end

  ##### boolean parameters #####

  def test_name_with_observations_with_comments
    expects = Name.index_order.with_correct_spelling.
              joins(observations: :comments).distinct
    assert_query(expects, :Name, with_observations: 1, with_comments: true)
  end

  def test_name_with_observations_with_public_lat_lng
    expects = Name.index_order.joins(:observations).
              where.not(observations: { lat: false }).distinct
    assert_query(
      expects, :Name, with_observations: 1, with_public_lat_lng: true
    )
  end

  def test_name_with_observations_with_name
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(observations: { name_id: Name.unknown }).distinct
    assert_query(expects, :Name, with_observations: 1, with_name: false)
  end

  def test_name_with_observations_with_notes
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where.not(observations: { notes: Observation.no_notes }).distinct
    assert_query(expects, :Name, with_observations: 1, with_notes: true)
  end

  def test_name_with_observations_with_sequences
    expects = Name.index_order.with_correct_spelling.
              joins(observations: :sequences).distinct
    assert_query(expects, :Name, with_observations: 1, with_sequences: true)
  end

  def test_name_with_observations_is_collection_location
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(observations: { is_collection_location: true }).distinct
    assert_query(
      expects, :Name, with_observations: 1, is_collection_location: true
    )
  end

  def test_name_with_observations_at_location
    loc = locations(:burbank)
    expects = Name.index_order.with_correct_spelling.joins(:observations).
              where(observations: { location: loc }).distinct
    assert_query(expects, :Name, with_observations: 1, location: loc)
  end

  def test_name_with_observations_at_where
    assert_query([names(:coprinus_comatus).id],
                 :Name, with_observations: 1, user_where: "glendale")
  end

  def test_name_with_observations_by_user
    assert_query(name_with_observations_by_user(rolf),
                 :Name, with_observations: 1, by_user: rolf)
    assert_query(name_with_observations_by_user(mary),
                 :Name, with_observations: 1, by_user: mary)
    assert_query([], :Name, with_observations: 1, by_user: users(:zero_user))
  end

  def name_with_observations_by_user(user)
    Name.index_order.with_correct_spelling.joins(:observations).
      where(observations: { user: user }).distinct
  end

  def test_name_with_observations_for_project
    project = projects(:empty_project)
    assert_query([], :Name, with_observations: 1, project: project)

    project2 = projects(:two_img_obs_project)
    expects = Name.index_order.with_correct_spelling.
              joins({ observations: :project_observations }).
              where(project_observations: { project: project2 }).distinct
    assert_query(expects, :Name, with_observations: 1, project: project2)
  end

  def test_name_with_observations_in_set
    oids = three_amigos.join(",")
    expects = Name.with_correct_spelling.joins(:observations).
              where(observations: { id: three_amigos }).
              reorder(
                Arel.sql("FIND_IN_SET(observations.id,'#{oids}')").asc,
                id: :desc
              ).distinct
    assert_query(expects, :Name, with_observations: 1, obs_ids: three_amigos)
  end

  def test_name_with_observations_in_species_list
    spl = species_lists(:unknown_species_list)
    expects = Name.index_order.with_correct_spelling.
              joins({ observations: :species_list_observations }).
              where(species_list_observations: { species_list: spl }).uniq
    assert_query(expects, :Name, with_observations: 1, species_list: spl)

    spl2 = species_lists(:first_species_list)
    assert_query([], :Name, with_observations: 1, species_list: spl2)
  end
end
