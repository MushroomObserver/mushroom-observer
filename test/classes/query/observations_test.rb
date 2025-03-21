# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Observations class to be included in QueryTest
class Query::ObservationsTest < UnitTestCase
  include QueryExtensions

  def test_observation_all
    expects = Observation.index_order
    assert_query(expects, :Observation)
  end

  # Overwrites scope `order_by_rss_log` in abstract_model
  def test_observation_by_rss_log
    expects = Observation.order_by_rss_log
    assert_query(expects, :Observation, by: :rss_log)
  end

  def big_set
    [
      observations(:unknown_with_no_naming),
      observations(:minimal_unknown_obs),
      observations(:strobilurus_diminutivus_obs),
      observations(:detailed_unknown_obs),
      observations(:agaricus_campestros_obs),
      observations(:coprinus_comatus_obs),
      observations(:agaricus_campestras_obs),
      observations(:agaricus_campestris_obs),
      observations(:agaricus_campestrus_obs)
    ].freeze
  end

  def test_observation_ids_ids
    assert_query(big_set.map(&:id), :Observation, id_in_set: big_set.map(&:id))
  end

  def test_observation_ids_instances
    assert_query(big_set.map(&:id), :Observation, id_in_set: big_set)
  end

  def test_observation_by_user
    expects = Observation.reorder(id: :asc).where(user: rolf.id).to_a
    assert_query(expects, :Observation, by_users: rolf, by: :id)
    expects = Observation.reorder(id: :asc).where(user: mary.id).to_a
    assert_query(expects, :Observation, by_users: mary, by: :id)
    expects = Observation.reorder(id: :asc).where(user: dick.id).to_a
    assert_query(expects, :Observation, by_users: dick, by: :id)
    assert_query([], :Observation, by_users: junk, by: :id)
  end

  def test_observation_confidence
    assert_query(Observation.index_order.confidence(50, 70),
                 :Observation, confidence: [50, 70])
    assert_query(Observation.index_order.confidence(100),
                 :Observation, confidence: [100])
  end

  def test_observation_has_public_lat_lng
    assert_query(Observation.index_order.has_public_lat_lng(true),
                 :Observation, has_public_lat_lng: true)
    assert_query(Observation.index_order.has_public_lat_lng(false),
                 :Observation, has_public_lat_lng: false)
  end

  def test_observation_is_collection_location
    assert_query(Observation.index_order.is_collection_location(true),
                 :Observation, is_collection_location: true)
    assert_query(Observation.index_order.is_collection_location(false),
                 :Observation, is_collection_location: false)
  end

  def test_observation_has_notes
    assert_query(Observation.index_order.has_notes(true),
                 :Observation, has_notes: true)
    assert_query(Observation.index_order.has_notes(false),
                 :Observation, has_notes: false)
  end

  def test_observation_notes_has
    assert_query(Observation.index_order.notes_has("strange place"),
                 :Observation, notes_has: "strange place")
    assert_query(Observation.index_order.notes_has("From"),
                 :Observation, notes_has: "From")
    assert_query(Observation.index_order.notes_has("Growing"),
                 :Observation, notes_has: "Growing")
  end

  def test_observation_has_notes_fields
    # the single version
    assert_query(Observation.index_order.has_notes_field("substrate"),
                 :Observation, has_notes_fields: "substrate")
    assert_query(Observation.index_order.
                 has_notes_fields(%w[substrate cap]),
                 :Observation, has_notes_fields: %w[substrate cap])
  end

  def test_observation_has_comments
    assert_query(Observation.index_order.has_comments(true),
                 :Observation, has_comments: true)
    assert_query(Observation.index_order,
                 :Observation, has_comments: false)
  end

  def test_observation_comments_has
    assert_query(Observation.index_order.comments_has("comment"),
                 :Observation, comments_has: "comment")
    assert_query(Observation.index_order.
                 comments_has("Agaricus campestris"),
                 :Observation, comments_has: "Agaricus campestris")
  end

  def test_observation_has_sequences
    assert_query(Observation.index_order.has_sequences(true),
                 :Observation, has_sequences: true)
    assert_query(Observation.index_order,
                 :Observation, has_sequences: false)
  end

  def test_observation_has_images
    assert_query(Observation.index_order.has_images(true),
                 :Observation, has_images: true)
    assert_query(Observation.index_order.has_images(false),
                 :Observation, has_images: false)
  end

  def test_observation_has_specimen
    assert_query(Observation.index_order.has_specimen(true),
                 :Observation, has_specimen: true)
    assert_query(Observation.index_order.has_specimen(false),
                 :Observation, has_specimen: false)
  end

  def test_observation_field_slips
    f_s = field_slips(:field_slip_one)
    assert_query([observations(:minimal_unknown_obs)],
                 :Observation, field_slips: f_s.code)
    fs2 = field_slips(:field_slip_falmouth_one)
    assert_query([observations(:falmouth_2022_obs),
                  observations(:minimal_unknown_obs)],
                 :Observation, field_slips: [f_s.id, fs2.id])
    assert_query(Observation.index_order.field_slips([f_s.code, fs2.code]),
                 :Observation, field_slips: [f_s.code, fs2.code])
    assert_query(Observation.index_order.field_slips([f_s.id, fs2.id]),
                 :Observation, field_slips: [f_s.id, fs2.id])
  end

  def test_observation_herbarium_records
    h_r = herbarium_records(:interesting_unknown)
    assert_query([observations(:detailed_unknown_obs),
                  observations(:minimal_unknown_obs)],
                 :Observation, herbarium_records: h_r.id)
    assert_query(Observation.index_order.herbarium_records(h_r),
                 :Observation, herbarium_records: h_r.id)
  end

  def test_observation_herbaria
    herb = herbaria(:fundis_herbarium)
    assert_query([observations(:detailed_unknown_obs)],
                 :Observation, herbaria: herb.name)
    assert_query(Observation.index_order.herbaria(herb.name),
                 :Observation, herbaria: herb.name)
    herb = herbaria(:nybg_herbarium)
    assert_query(Observation.index_order.herbaria(herb.name),
                 :Observation, herbaria: herb.id)
  end

  def test_observation_on_project_lists
    projects = [projects(:bolete_project), projects(:eol_project)]
    expects = Observation.index_order.project_lists(projects)
    assert_query(expects, :Observation, project_lists: projects.map(&:title))
  end

  def test_observation_locations
    expects = Observation.index_order.locations(locations(:burbank)).distinct
    assert_query(expects, :Observation, locations: locations(:burbank))
  end

  def test_observation_projects
    assert_query([],
                 :Observation, projects: projects(:empty_project))
    project = projects(:bolete_project)
    assert_query(project.observations, :Observation, projects: project)
    assert_query(Observation.index_order.projects(project.title),
                 :Observation, projects: project)
  end

  def test_observation_projects_equivalence
    qu1 = Query.lookup_and_save(:Observation,
                                projects: projects(:bolete_project))
    qu2 = Query.lookup_and_save(:Observation,
                                projects: projects(:bolete_project).id.to_s)
    assert_equal(qu1.results, qu2.results)
  end

  def test_observation_species_lists
    spl = species_lists(:unknown_species_list)
    # These two are identical, so should be disambiguated by reverse_id.
    assert_query([observations(:detailed_unknown_obs).id,
                  observations(:minimal_unknown_obs).id],
                 :Observation, species_lists: spl.id)
    assert_query(Observation.index_order.species_lists(spl),
                 :Observation, species_lists: spl.id)
    # check the other param!
    assert_query(Observation.index_order.species_lists(spl),
                 :Observation, species_lists: spl.id)
    spl2 = species_lists(:one_genus_three_species_list)
    assert_query(Observation.index_order.species_lists([spl, spl2]).distinct,
                 :Observation, species_lists: [spl.title, spl2.title])
  end

  def test_observation_clade
    assert_query(Observation.index_order.clade("Agaricales"),
                 :Observation, clade: "Agaricales")
    assert_query(Observation.index_order.clade("Tremellales"),
                 :Observation, clade: "Tremellales")
  end

  def test_observation_region
    assert_query(Observation.index_order.
                 region("Sonoma Co., California, USA"),
                 :Observation, region: "Sonoma Co., California, USA")
    assert_query(Observation.index_order.region("Massachusetts, USA"),
                 :Observation, region: "Massachusetts, USA")
    assert_query(Observation.index_order.region("North America"),
                 :Observation, region: "North America")
  end

  def test_observation_in_box
    # Have to do this, otherwise columns not populated
    Location.update_box_area_and_center_columns
    box = { north: 35, south: 34, east: -118, west: -119 }
    assert_query(Observation.index_order.in_box(**box),
                 :Observation, in_box: box)
  end

  def test_observation_of_children
    name = names(:agaricus)
    expects = Observation.index_order.
              names(lookup: name, include_subtaxa: true).distinct
    assert_query(expects, :Observation, names: { lookup: [name.id],
                                                 include_subtaxa: true })
  end

  # This test ensures we force empty results when the lookup gets no ids.
  def test_observation_of_subtaxa_excluding_original_no_children
    name = names(:tubaria_furfuracea)
    assert_query_scope(
      [],
      Observation.index_order.names(lookup: name.id,
                                    include_subtaxa: true,
                                    exclude_original_names: true),
      :Observation, names: { lookup: name.id,
                             include_subtaxa: true,
                             exclude_original_names: true }
    )
  end

  def test_observation_names_with_modifiers
    User.current = rolf
    expects = Observation.index_order.names(lookup: names(:fungi)).distinct
    assert_query(expects, :Observation, names: { lookup: [names(:fungi).id] })
    assert_query(
      [],
      :Observation, names: { lookup: [names(:macrolepiota_rachodes).id] }
    )

    # test all truthy/falsy combinations of these boolean parameters:
    #  include_synonyms, include_all_name_proposals, exclude_consensus
    names = Name.index_order.
            where(Name[:text_name].matches("Agaricus camp%")).to_a
    agaricus_ssp = names.clone
    name = names.pop
    names.each { |n| name.merge_synonyms(n) }
    observations(:agaricus_campestras_obs).update(user: mary)
    observations(:agaricus_campestros_obs).update(user: mary)

    # observations where name(s) is consensus
    assert_query(
      [observations(:agaricus_campestris_obs).id],
      :Observation, names: { lookup: [names(:agaricus_campestris).id],
                             include_synonyms: false,
                             include_all_name_proposals: false,
                             exclude_consensus: false }
    )

    # name(s) is consensus, but is not the consensus (an oxymoron)
    assert_query(
      [],
      :Observation, names: { lookup: [names(:agaricus_campestris).id],
                             include_synonyms: false,
                             include_all_name_proposals: false,
                             exclude_consensus: true }
    )

    # name(s) is proposed
    assert_query(
      [observations(:agaricus_campestris_obs).id,
       observations(:coprinus_comatus_obs).id],
      :Observation, names: { lookup: [names(:agaricus_campestris).id],
                             include_synonyms: false,
                             include_all_name_proposals: true,
                             exclude_consensus: false }
    )

    # name(s) is proposed, but is not the consensus
    assert_query(
      [observations(:coprinus_comatus_obs).id],
      :Observation, names: { lookup: [names(:agaricus_campestris).id],
                             include_synonyms: false,
                             include_all_name_proposals: true,
                             exclude_consensus: true }
    )

    # consensus is a synonym of name(s)
    assert_query(
      [observations(:agaricus_campestros_obs).id,
       observations(:agaricus_campestras_obs).id,
       observations(:agaricus_campestrus_obs).id,
       observations(:agaricus_campestris_obs).id],
      :Observation, names: { lookup: [names(:agaricus_campestris).id],
                             include_synonyms: true,
                             include_all_name_proposals: false,
                             exclude_consensus: false }
    )

    # same as above but exclude_original_names
    # conensus is a synonym of name(s) other than name(s)
    assert_query(
      [observations(:agaricus_campestros_obs).id,
       observations(:agaricus_campestras_obs).id,
       observations(:agaricus_campestrus_obs).id],
      :Observation, names: { lookup: [names(:agaricus_campestris).id],
                             include_synonyms: true,
                             exclude_original_names: true }
    )

    # consensus is a synonym of name(s) but not a synonym of name(s) (oxymoron)
    assert_query(
      [],
      :Observation, names: { lookup: [names(:agaricus_campestras).id],
                             include_synonyms: true,
                             include_all_name_proposals: false,
                             exclude_consensus: true }
    )

    # where synonyms of names are proposed
    assert_query(
      [observations(:agaricus_campestros_obs).id,
       observations(:agaricus_campestras_obs).id,
       observations(:agaricus_campestrus_obs).id,
       observations(:agaricus_campestris_obs).id,
       observations(:coprinus_comatus_obs).id],
      :Observation, names: { lookup: [names(:agaricus_campestris).id],
                             include_synonyms: true,
                             include_all_name_proposals: true,
                             exclude_consensus: false }
    )

    # where synonyms of name are proposed, but are not the consensus
    assert_query(
      [observations(:coprinus_comatus_obs).id],
      :Observation, names: { lookup: [names(:agaricus_campestras).id],
                             include_synonyms: true,
                             include_all_name_proposals: true,
                             exclude_consensus: true }
    )

    spl = species_lists(:first_species_list)
    spl.observations << observations(:agaricus_campestrus_obs)
    spl.observations << observations(:agaricus_campestros_obs)
    proj = projects(:eol_project)
    proj.observations << observations(:agaricus_campestris_obs)
    proj.observations << observations(:agaricus_campestras_obs)

    assert_query(
      [observations(:agaricus_campestros_obs).id,
       observations(:agaricus_campestrus_obs).id],
      :Observation, names: { lookup: agaricus_ssp.map(&:text_name) },
                    species_lists: [spl.title]
    )

    assert_query(
      [observations(:agaricus_campestras_obs).id,
       observations(:agaricus_campestris_obs).id],
      :Observation, names: { lookup: agaricus_ssp.map(&:text_name) },
                    projects: [proj.title]
    )
  end

  # notes search disabled because it may mention other species.
  # deemed confusing for users.
  # def test_observation_pattern_search_notes
  #   assert_query(observation_pattern_search('"somewhere else"'),
  #                :Observation, pattern: '"somewhere else"')
  # end

  def test_observation_pattern_search_where
    assert_query([observations(:strobilurus_diminutivus_obs).id],
                 :Observation, pattern: "pipi valley")
  end

  def test_observation_pattern_search_location
    assert_query(observation_pattern_search("burbank"),
                 :Observation, pattern: "burbank")
  end

  def test_observation_pattern_search_name
    assert_query(observation_pattern_search("agaricus"),
                 :Observation, pattern: "agaricus")
  end

  def observation_pattern_search(pattern)
    Observation.index_order.pattern(pattern).distinct
  end

  def test_observation_advanced_search_name
    assert_query([observations(:strobilurus_diminutivus_obs).id],
                 :Observation, search_name: "diminutivus")
  end

  def test_observation_advanced_search_where
    assert_query([observations(:coprinus_comatus_obs).id],
                 :Observation, search_where: "glendale") # where
    expects = Observation.reorder(id: :asc).
              where(location: locations(:burbank)).distinct
    assert_query(expects,
                 :Observation, search_where: "burbank", by: :id) # location
  end

  def test_observation_advanced_search_user
    expects = Observation.reorder(id: :asc).where(user: rolf.id).distinct
    assert_query(expects, :Observation, search_user: "rolf", by: :id)
  end

  def test_observation_advanced_search_content
    # notes
    expects = [observations(:coprinus_comatus_obs)]
    scope = Observation.search_content("second fruiting")
    assert_query_scope(expects, scope,
                       :Observation, search_content: "second fruiting")
    # comments(:minimal_unknown_obs_comment_2)
    expects = [observations(:minimal_unknown_obs)]
    scope = Observation.search_content("agaricus")
    assert_query_scope(expects, scope,
                       :Observation, search_content: "agaricus")
  end

  def test_observation_date
    # blank should return all
    assert_query(Observation.index_order, :Observation, date: nil)
    # impossible dates should return none
    assert_query([], :Observation, date: %w[1550 1551])
    # single date should return after
    assert_query(Observation.index_order.date("2011-05-12"),
                 :Observation, date: "2011-05-12")
    # single date within array should also return after
    assert_query(Observation.index_order.date(["2011-05-12"]),
                 :Observation, date: "2011-05-12")
    # year should return after
    assert_query(Observation.index_order.date("2005"),
                 :Observation, date: "2005")
    # years should return between
    assert_query(Observation.index_order.date("2005", "2009"),
                 :Observation, date: %w[2005 2009])
    # test scope accepts array values
    assert_query(Observation.index_order.date(%w[2005 2009]),
                 :Observation, date: %w[2005 2009])
    # in a month range, any year
    assert_query(Observation.index_order.date("05", "12"),
                 :Observation, date: %w[05 12])
    # in a month range, any year, within array
    assert_query(Observation.index_order.date(%w[05 12]),
                 :Observation, date: %w[05 12])
    # in a date range, any year
    assert_query(Observation.index_order.date("02-22", "08-22"),
                 :Observation, date: %w[02-22 08-22])
    # period wraps around the new year
    assert_query(Observation.index_order.date("08-22", "02-22"),
                 :Observation, date: %w[08-22 02-22])
    # full dates
    assert_query(Observation.index_order.date("2009-08-22", "2009-10-20"),
                 :Observation, date: %w[2009-08-22 2009-10-20])
    # date wraps around the new year
    assert_query(Observation.index_order.date("2015-08-22", "2016-02-22"),
                 :Observation, date: %w[2015-08-22 2016-02-22])
    # as array
    assert_query(Observation.index_order.date(%w[2015-08-22 2016-02-22]),
                 :Observation, date: %w[2015-08-22 2016-02-22])
  end

  def test_observation_created_at
    do_datetime_test(:created_at)
  end

  def test_observation_updated_at
    do_datetime_test(:updated_at)
  end

  def do_datetime_test(col)
    # blank should return all
    assert_query(Observation.index_order, :Observation, "#{col}": nil)
    # impossible dates should return none
    assert_query([], :Observation, "#{col}": %w[2000 2001])
    # single datetime should return after
    assert_query(Observation.index_order.send(col, "2011-05-12-12-59-57"),
                 :Observation, "#{col}": "2011-05-12-12-59-57")
    # single date should return after
    assert_query(Observation.index_order.send(col, "2011-05-12"),
                 :Observation, "#{col}": "2011-05-12")
    # year should return after 01/01
    assert_query(Observation.index_order.send(col, "2005-01-01"),
                 :Observation, "#{col}": "2005")
    # month should return after 01
    assert_query(Observation.index_order.send(col, "2007-05-01"),
                 :Observation, "#{col}": "2007-05")
    # years should return between
    assert_query(Observation.index_order.send(col, "2005", "2009"),
                 :Observation, "#{col}": %w[2005 2009])
    # test scope accepts array values
    assert_query(Observation.index_order.send(col, %w[2005 2009]),
                 :Observation, "#{col}": %w[2005 2009])
    # test that reversed value order works in scope
    assert_query(Observation.index_order.send(col, %w[2009 2005]),
                 :Observation, "#{col}": %w[2005 2009])
    # full dates
    assert_query(Observation.index_order.send(col, "2009-08-22", "2009-10-20"),
                 :Observation, "#{col}": %w[2009-08-22 2009-10-20])
    # full datetimes
    assert_query(Observation.index_order.
                 send(col, "2009-08-22-03-04-22", "2009-10-20-03-04-22"),
                 :Observation,
                 "#{col}": %w[2009-08-22-03-04-22 2009-10-20-03-04-22])
    # as array
    assert_query(Observation.index_order.
                 send(col, %w[2009-08-22-03-04-22 2009-10-20-03-04-22]),
                 :Observation,
                 "#{col}": %w[2009-08-22-03-04-22 2009-10-20-03-04-22])
  end
end
