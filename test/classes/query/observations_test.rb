# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Observations class to be included in QueryTest
class Query::ObservationsTest < UnitTestCase
  include QueryExtensions

  def test_observation_all
    expects = Observation.order_by_default
    assert_query(expects, :Observation)
  end

  def test_observation_order_by_confidence
    expects = Observation.order_by(:confidence)
    assert_query(expects, :Observation, order_by: :confidence)
  end

  def test_observation_order_by_created_at
    expects = Observation.order_by(:created_at)
    assert_query(expects, :Observation, order_by: :created_at)
  end

  def test_observation_order_by_date
    expects = Observation.order_by(:date)
    assert_query(expects, :Observation, order_by: :date)
  end

  def test_observation_order_by_location
    expects = Observation.order_by(:location)
    assert_query(expects, :Observation, order_by: :location)
  end

  # Test that subquery `reorder("")` does not interfere with explicit order.
  def test_observation_order_by_name
    expects = Observation.location_query(pattern: "Falmouth").order_by(:name)
    assert_query(
      expects,
      :Observation, location_query: { pattern: "Falmouth" }, order_by: :name
    )
  end

  def test_observation_order_by_user
    expects = Observation.name_query(pattern: "Agaricus").order_by(:user)
    assert_query(
      expects,
      :Observation, name_query: { pattern: "Agaricus" }, order_by: :user
    )
  end

  def test_observation_order_by_num_views
    expects = Observation.order_by(:num_views)
    assert_query(expects, :Observation, order_by: :num_views)
  end

  def test_image_order_by_owners_thumbnail_quality
    expects = Observation.order_by(:owners_thumbnail_quality)
    assert_query(expects, :Observation, order_by: :owners_thumbnail_quality)
  end

  def test_observation_order_by_rss_log
    expects = Observation.order_by(:rss_log)
    assert_query(expects, :Observation, order_by: :rss_log)
  end

  def test_image_order_by_thumbnail_quality
    expects = Observation.order_by(:thumbnail_quality)
    assert_query(expects, :Observation, order_by: :thumbnail_quality)
  end

  def test_observation_order_by_updated_at
    expects = Observation.order_by(:updated_at)
    assert_query(expects, :Observation, order_by: :updated_at)
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

  def test_observation_id_in_set_with_ids
    set = big_set.map(&:id)
    scope = Observation.id_in_set(set)
    assert_query_scope(set, scope, :Observation, id_in_set: set)
  end

  def test_observation_id_in_set_with_instances
    set = big_set
    scope = Observation.id_in_set(set)
    assert_query_scope(set, scope, :Observation, id_in_set: set)
  end

  def test_observation_by_users
    users = [mary, dick, rolf]
    users.each do |user|
      expects = Observation.where(user:).order_by(:id)
      scope = Observation.by_users(user).order_by(:id)
      assert_query_scope(expects, scope,
                         :Observation, by_users: user, order_by: :id)
      scope = Observation.by_users(user.login).order_by(:id)
      assert_query_scope(expects, scope,
                         :Observation, by_users: user.login, order_by: :id)
    end
    assert_query([], :Observation, by_users: users(:junk))
  end

  def test_observation_confidence
    assert_query(Observation.confidence(50, 70).order_by_default,
                 :Observation, confidence: [50, 70])
    assert_query(Observation.confidence(100).order_by_default,
                 :Observation, confidence: [100])
  end

  def test_observation_has_public_lat_lng
    assert_query(Observation.has_public_lat_lng(true).order_by_default,
                 :Observation, has_public_lat_lng: true)
    assert_query(Observation.has_public_lat_lng(false).order_by_default,
                 :Observation, has_public_lat_lng: false)
  end

  def test_observation_is_collection_location
    assert_query(Observation.is_collection_location(true).order_by_default,
                 :Observation, is_collection_location: true)
    assert_query(Observation.is_collection_location(false).order_by_default,
                 :Observation, is_collection_location: false)
  end

  def test_observation_has_notes
    assert_query(Observation.has_notes(true).order_by_default,
                 :Observation, has_notes: true)
    assert_query(Observation.has_notes(false).order_by_default,
                 :Observation, has_notes: false)
  end

  def test_observation_notes_has
    assert_query(Observation.notes_has("strange place").order_by_default,
                 :Observation, notes_has: "strange place")
    assert_query(Observation.notes_has("From").order_by_default,
                 :Observation, notes_has: "From")
    assert_query(Observation.notes_has("Growing").order_by_default,
                 :Observation, notes_has: "Growing")
  end

  def test_observation_has_notes_fields
    # the single version
    assert_query(
      Observation.has_notes_field("substrate").order_by_default,
      :Observation, has_notes_fields: "substrate"
    )
    assert_query(
      Observation.has_notes_fields(%w[substrate cap]).order_by_default,
      :Observation, has_notes_fields: %w[substrate cap]
    )
  end

  def test_observation_has_comments
    assert_query(Observation.has_comments(true).order_by_default,
                 :Observation, has_comments: true)
    assert_query(Observation.order_by_default,
                 :Observation, has_comments: false)
  end

  def test_observation_comments_has
    assert_query(
      Observation.comments_has("comment").order_by_default,
      :Observation, comments_has: "comment"
    )
    assert_query(
      Observation.comments_has("Agaricus campestris").order_by_default,
      :Observation, comments_has: "Agaricus campestris"
    )
  end

  def test_observation_has_sequences
    assert_query(Observation.has_sequences(true).order_by_default,
                 :Observation, has_sequences: true)
    assert_query(Observation.order_by_default,
                 :Observation, has_sequences: false)
  end

  def test_observation_has_images
    assert_query(Observation.has_images(true).order_by_default,
                 :Observation, has_images: true)
    assert_query(Observation.has_images(false).order_by_default,
                 :Observation, has_images: false)
  end

  def test_observation_has_specimen
    assert_query(Observation.has_specimen(true).order_by_default,
                 :Observation, has_specimen: true)
    assert_query(Observation.has_specimen(false).order_by_default,
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
    assert_query(Observation.field_slips([f_s.code, fs2.code]).order_by_default,
                 :Observation, field_slips: [f_s.code, fs2.code])
    assert_query(Observation.field_slips([f_s.id, fs2.id]).order_by_default,
                 :Observation, field_slips: [f_s.id, fs2.id])
  end

  def test_observation_herbarium_records
    h_r = herbarium_records(:interesting_unknown)
    assert_query_scope([observations(:detailed_unknown_obs),
                        observations(:minimal_unknown_obs)],
                       Observation.herbarium_records(h_r).order_by_default,
                       :Observation, herbarium_records: h_r.id)
  end

  def test_observation_herbaria
    herb = herbaria(:fundis_herbarium)
    assert_query([observations(:detailed_unknown_obs)],
                 :Observation, herbaria: herb.name)
    assert_query(Observation.herbaria(herb.name).order_by_default,
                 :Observation, herbaria: herb.name)
    herb = herbaria(:nybg_herbarium)
    assert_query(Observation.herbaria(herb.name).order_by_default,
                 :Observation, herbaria: herb.id)
  end

  def test_observation_on_project_lists
    projects = [projects(:bolete_project), projects(:eol_project)]
    expects = Observation.project_lists(projects).order_by_default
    assert_query(expects, :Observation, project_lists: projects.map(&:title))
  end

  def test_observation_locations
    expects = Observation.locations(locations(:burbank)).order_by_default
    assert_query(expects, :Observation, locations: locations(:burbank))
  end

  def test_observation_locations_multiple
    locs = [locations(:burbank), locations(:mitrula_marsh)]
    expects = Observation.locations(locs).order_by_default
    assert_query(expects, :Observation, locations: locs.map(&:name))

    expects = Observation.locations(locs.map(&:id)).order_by_default
    assert_query(expects, :Observation, locations: locs.map(&:id))

    expects = Observation.locations(locs.map(&:name)).order_by_default
    assert_query(expects, :Observation, locations: locs.map(&:id))
  end

  def test_observation_within_locations
    expects = Observation.within_locations(locations(:california)).
              order_by_default
    assert_query(expects, :Observation,
                 within_locations: locations(:california))
  end

  def test_observation_projects
    assert_query([],
                 :Observation, projects: projects(:empty_project))
    project = projects(:bolete_project)
    assert_query(project.observations, :Observation, projects: project)
    assert_query(Observation.projects(project.title).order_by_default,
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
    assert_query(Observation.species_lists(spl).order_by_default,
                 :Observation, species_lists: spl.id)
    # check the other param!
    assert_query(Observation.species_lists(spl).order_by_default,
                 :Observation, species_lists: spl.id)
    spl2 = species_lists(:one_genus_three_species_list)
    assert_query(Observation.species_lists([spl, spl2]).order_by_default,
                 :Observation, species_lists: [spl.title, spl2.title])
  end

  def test_observation_clade
    assert_query(Observation.clade("Agaricales").order_by_default,
                 :Observation, clade: "Agaricales")
    assert_query(Observation.clade("Tremellales").order_by_default,
                 :Observation, clade: "Tremellales")
  end

  def test_observation_region
    assert_query(Observation.
                 region("Sonoma Co., California, USA").order_by_default,
                 :Observation, region: "Sonoma Co., California, USA")
    assert_query(Observation.region("Massachusetts, USA").order_by_default,
                 :Observation, region: "Massachusetts, USA")
    assert_query(Observation.region("North America").order_by_default,
                 :Observation, region: "North America")
  end

  def test_observation_in_box
    box = { north: 35, south: 34, east: -118, west: -119 }
    assert_query(Observation.in_box(**box).order_by_default,
                 :Observation, in_box: box)
  end

  # `in_box` originally had a badly-formed `or` that did not preserve the
  # original scope on both branches of the `or` condition. The result was
  # that a chained `in_box` query returned (seemingly) everything `in_box`.
  def test_observation_in_box_with_other_scopes
    # Have to do this, otherwise columns not populated
    Location.update_box_area_and_center_columns
    box = { north: 35, south: 34, east: -118, west: -119 }
    in_box_expects = Query.lookup(:Observation, in_box: box)
    # be sure we have more than one user's obs in this box
    box_users = in_box_expects.results.pluck(:user_id).uniq
    assert(box_users.size > 1)
    assert(box_users.include?(mary.id))

    chained_expects = Query.lookup(:Observation, in_box: box, by_users: mary.id)
    assert_not_equal(in_box_expects.result_ids, chained_expects.result_ids)

    box = locations(:california).bounding_box
    in_box_expects = Query.lookup(:Observation, in_box: box)
    # be sure we have more than one value in this box
    box_names = in_box_expects.results.pluck(:name_id).uniq
    assert(box_names.size > 1)

    chained_expects = Query.lookup(
      :Observation, in_box: box,
                    names: {
                      lookup: "Agaricus campestris",
                      include_synonyms: true
                    }
    )
    assert_not_equal(in_box_expects.result_ids, chained_expects.result_ids)
  end

  def test_observation_of_children
    name = names(:agaricus)
    params = { lookup: name.id, include_subtaxa: true }
    expects = Observation.names(**params).order_by_default
    assert_query(expects, :Observation, names: params)
  end

  # This test ensures we force empty results when the lookup gets no ids.
  def test_observation_of_subtaxa_excluding_original_no_children
    name = names(:tubaria_furfuracea)
    assert_query_scope(
      [],
      Observation.names(lookup: name.id,
                        include_subtaxa: true,
                        exclude_original_names: true).order_by_default,
      :Observation, names: { lookup: name.id,
                             include_subtaxa: true,
                             exclude_original_names: true }
    )
  end

  def test_observation_names_with_no_modifiers
    params = { lookup: [names(:fungi).id] }
    scope = Observation.names(**params).order_by_default
    assert_query(scope, :Observation, names: params)
    assert_query(
      [],
      :Observation, names: { lookup: [names(:macrolepiota_rachodes).id] }
    )
  end

  # Setup for testing all truthy/falsy combinations of these boolean parameters:
  #   include_synonyms, include_all_name_proposals, exclude_consensus
  # Returns the agaricus synonyms needed by some tests
  def setup_observation_names_agaricus_synonymns
    names = Name.where(Name[:text_name].matches("Agaricus camp%")).
            order_by_default.to_a
    agaricus_ssp = names.clone
    name = names.pop
    names.each { |n| name.merge_synonyms(n) }
    observations(:agaricus_campestras_obs).update(user: mary)
    observations(:agaricus_campestros_obs).update(user: mary)
    agaricus_ssp
  end

  def test_observation_names_is_consensus
    setup_observation_names_agaricus_synonymns
    params = { lookup: [names(:agaricus_campestris).id],
               include_synonyms: false,
               include_all_name_proposals: false,
               exclude_consensus: false }
    scope = Observation.names(**params).order_by_default
    assert_query_scope(
      [observations(:agaricus_campestris_obs).id], scope,
      :Observation, names: params
    )
  end

  def test_observation_names_is_consensus_exclude_consensus
    setup_observation_names_agaricus_synonymns
    params = { lookup: [names(:agaricus_campestris).id],
               include_synonyms: false,
               include_all_name_proposals: false,
               exclude_consensus: true }
    scope = Observation.names(**params).order_by_default
    assert_query_scope(
      [], scope, :Observation, names: params
    )
  end

  def test_observation_names_is_proposed
    setup_observation_names_agaricus_synonymns
    params = { lookup: [names(:agaricus_campestris).id],
               include_synonyms: false,
               include_all_name_proposals: true,
               exclude_consensus: false }
    scope = Observation.names(**params).order_by_default
    assert_query_scope(
      [observations(:agaricus_campestris_obs).id,
       observations(:coprinus_comatus_obs).id],
      scope,
      :Observation, names: params
    )
  end

  def test_observation_names_is_proposed_but_not_consensus_explicit
    setup_observation_names_agaricus_synonymns
    params = { lookup: [names(:agaricus_campestris).id],
               include_synonyms: false,
               include_all_name_proposals: true,
               exclude_consensus: true }
    scope = Observation.names(**params).order_by_default
    assert_query_scope(
      [observations(:coprinus_comatus_obs).id],
      scope,
      :Observation, names: params
    )
  end

  # No need to pass include_all_name_proposals: true if exclude_consensus: true
  def test_observation_names_is_proposed_but_not_consensus_simple
    setup_observation_names_agaricus_synonymns
    params = { lookup: [names(:agaricus_campestris).id],
               include_synonyms: false,
               exclude_consensus: true }
    scope = Observation.names(**params).order_by_default
    assert_query_scope(
      [observations(:coprinus_comatus_obs).id],
      scope,
      :Observation, names: params
    )
  end

  def test_observation_names_consensus_is_synonym_of_name
    setup_observation_names_agaricus_synonymns
    params = { lookup: [names(:agaricus_campestris).id],
               include_synonyms: true,
               include_all_name_proposals: false,
               exclude_consensus: false }
    scope = Observation.names(**params).order_by_default
    assert_query_scope(
      [observations(:agaricus_campestros_obs).id,
       observations(:agaricus_campestras_obs).id,
       observations(:agaricus_campestrus_obs).id,
       observations(:agaricus_campestris_obs).id],
      scope,
      :Observation, names: params
    )
  end

  def test_observation_names_consensus_is_synonym_of_name_other_than_name
    setup_observation_names_agaricus_synonymns
    params = { lookup: [names(:agaricus_campestris).id],
               include_synonyms: true,
               exclude_original_names: true }
    scope = Observation.names(**params).order_by_default
    assert_query_scope(
      [observations(:agaricus_campestros_obs).id,
       observations(:agaricus_campestras_obs).id,
       observations(:agaricus_campestrus_obs).id],
      scope,
      :Observation, names: params
    )
  end

  def test_observation_names_consensus_is_synonym_of_name_but_excluded
    setup_observation_names_agaricus_synonymns
    params = { lookup: [names(:agaricus_campestras).id],
               include_synonyms: true,
               include_all_name_proposals: false,
               exclude_consensus: true }
    scope = Observation.names(**params).order_by_default
    assert_query_scope(
      [],
      scope,
      :Observation, names: params
    )
  end

  def test_observation_names_synonym_of_name_is_proposed
    setup_observation_names_agaricus_synonymns
    params = { lookup: [names(:agaricus_campestris).id],
               include_synonyms: true,
               include_all_name_proposals: true,
               exclude_consensus: false }
    scope = Observation.names(**params).order_by_default
    assert_query_scope(
      [observations(:agaricus_campestros_obs).id,
       observations(:agaricus_campestras_obs).id,
       observations(:agaricus_campestrus_obs).id,
       observations(:agaricus_campestris_obs).id,
       observations(:coprinus_comatus_obs).id],
      scope,
      :Observation, names: params
    )
  end

  def test_observation_names_synonym_of_name_is_proposed_but_not_consensus
    setup_observation_names_agaricus_synonymns
    params = { lookup: [names(:agaricus_campestras).id],
               include_synonyms: true,
               include_all_name_proposals: true,
               exclude_consensus: true }
    scope = Observation.names(**params).order_by_default
    assert_query_scope(
      [observations(:coprinus_comatus_obs).id],
      scope,
      :Observation, names: params
    )
  end

  def test_observation_names_in_species_lists_and_projects
    agaricus_ssp = setup_observation_names_agaricus_synonymns
    spl = species_lists(:first_species_list)
    spl.observations << observations(:agaricus_campestrus_obs)
    spl.observations << observations(:agaricus_campestros_obs)
    proj = projects(:eol_project)
    proj.observations << observations(:agaricus_campestris_obs)
    proj.observations << observations(:agaricus_campestras_obs)

    params = { lookup: agaricus_ssp.map(&:text_name) }
    scope = Observation.names(**params).species_lists(spl.title).
            order_by_default
    assert_query_scope(
      [observations(:agaricus_campestros_obs).id,
       observations(:agaricus_campestrus_obs).id],
      scope,
      :Observation, names: params, species_lists: [spl.title]
    )

    params = { lookup: agaricus_ssp.map(&:text_name) }
    scope = Observation.names(**params).projects(proj.title).
            order_by_default
    assert_query_scope(
      [observations(:agaricus_campestras_obs).id,
       observations(:agaricus_campestris_obs).id],
      scope,
      :Observation, names: params, projects: [proj.title]
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
    Observation.pattern(pattern).distinct.order_by_default
  end

  def test_observation_advanced_search_name
    assert_query_scope([observations(:strobilurus_diminutivus_obs).id],
                       Observation.search_name("diminutivus"),
                       :Observation, search_name: "diminutivus")
  end

  def test_observation_advanced_search_where
    assert_query_scope([observations(:coprinus_comatus_obs).id], # where
                       Observation.search_where("glendale"),
                       :Observation, search_where: "glendale")
    expects = Observation.order(id: :asc).
              where(location: locations(:burbank)).distinct # location
    scope = Observation.search_where("burbank").order(id: :asc)
    assert_query_scope(expects, scope,
                       :Observation, search_where: "burbank", order_by: :id)
  end

  def test_observation_advanced_search_user
    expects = Observation.order(id: :asc).where(user: rolf.id).distinct
    scope = Observation.search_user("rolf").order(id: :asc)
    assert_query_scope(expects, scope,
                       :Observation, search_user: "rolf", order_by: :id)
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
    assert_query(Observation.order_by_default, :Observation, date: nil)
    # impossible dates should return none
    assert_query([], :Observation, date: %w[1550 1551])
    # single date should return after
    assert_query(Observation.date("2011-05-12").order_by_default,
                 :Observation, date: "2011-05-12")
    # single date within array should also return after
    assert_query(Observation.date(["2011-05-12"]).order_by_default,
                 :Observation, date: "2011-05-12")
    # year should return after
    assert_query(Observation.date("2005").order_by_default,
                 :Observation, date: "2005")
    # years should return between
    assert_query(Observation.date("2005", "2009").order_by_default,
                 :Observation, date: %w[2005 2009])
    # test scope accepts array values
    assert_query(Observation.date(%w[2005 2009]).order_by_default,
                 :Observation, date: %w[2005 2009])
    # in a month range, any year
    assert_query(Observation.date("05", "12").order_by_default,
                 :Observation, date: %w[05 12])
    # in a month range, any year, within array
    assert_query(Observation.date(%w[05 12]).order_by_default,
                 :Observation, date: %w[05 12])
    # in a date range, any year
    assert_query(Observation.date("02-22", "08-22").order_by_default,
                 :Observation, date: %w[02-22 08-22])
    # period wraps around the new year
    assert_query(Observation.date("08-22", "02-22").order_by_default,
                 :Observation, date: %w[08-22 02-22])
    # full dates
    assert_query(Observation.date("2009-08-22", "2009-10-20").order_by_default,
                 :Observation, date: %w[2009-08-22 2009-10-20])
    # date wraps around the new year
    assert_query(Observation.date("2015-08-22", "2016-02-22").order_by_default,
                 :Observation, date: %w[2015-08-22 2016-02-22])
    # as array
    assert_query(Observation.date(%w[2015-08-22 2016-02-22]).order_by_default,
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
    assert_query(Observation.order_by_default, :Observation, "#{col}": nil)
    # impossible dates should return none
    assert_query([], :Observation, "#{col}": %w[2000 2001])
    # single datetime should return after
    assert_query(Observation.send(col, "2011-05-12-12-59-57").order_by_default,
                 :Observation, "#{col}": "2011-05-12-12-59-57")
    # single date should return after
    assert_query(Observation.send(col, "2011-05-12").order_by_default,
                 :Observation, "#{col}": "2011-05-12")
    # year should return after 01/01
    assert_query(Observation.send(col, "2005-01-01").order_by_default,
                 :Observation, "#{col}": "2005")
    # month should return after 01
    assert_query(Observation.send(col, "2007-05-01").order_by_default,
                 :Observation, "#{col}": "2007-05")
    # years should return between
    assert_query(Observation.send(col, "2005", "2009").order_by_default,
                 :Observation, "#{col}": %w[2005 2009])
    # test scope accepts array values
    assert_query(Observation.send(col, %w[2005 2009]).order_by_default,
                 :Observation, "#{col}": %w[2005 2009])
    # test that reversed value order works in scope
    assert_query(Observation.send(col, %w[2009 2005]).order_by_default,
                 :Observation, "#{col}": %w[2005 2009])
    # full dates
    assert_query(Observation.
                 send(col, "2009-08-22", "2009-10-20").order_by_default,
                 :Observation, "#{col}": %w[2009-08-22 2009-10-20])
    # full datetimes
    assert_query(
      Observation.
      send(col, "2009-08-22-03-04-22", "2009-10-20-03-04-22").order_by_default,
      :Observation, "#{col}": %w[2009-08-22-03-04-22 2009-10-20-03-04-22]
    )
    # as array
    assert_query(
      Observation.
      send(col, %w[2009-08-22-03-04-22 2009-10-20-03-04-22]).order_by_default,
      :Observation, "#{col}": %w[2009-08-22-03-04-22 2009-10-20-03-04-22]
    )
  end

  def test_observation_image_query
    images = Image.copyright_holder_has("rolf").pluck(:id)
    assert_query(
      Observation.where(thumb_image: images).order_by_default,
      :Observation, image_query: { copyright_holder_has: "rolf" }
    )
  end

  def test_observation_location_query_simple
    assert_query(
      Observation.where(location: locations(:burbank)).order_by_default,
      :Observation, location_query: { pattern: "Burbank" }
    )
  end

  def test_observation_location_query_in_box
    box = { north: 35, south: 34, east: -118, west: -119 }
    locations = Location.in_box(**box).by_users(mary)
    expects = Observation.joins(:location).distinct.
              where(location_id: locations).order_by_default
    assert_query(expects,
                 :Observation, location_query: { in_box: box, by_users: mary })
  end

  def test_observation_name_query_simple
    name = names(:peltigera)
    assert_query(
      Observation.where(name: name).order_by_default,
      :Observation, name_query: { pattern: name.text_name }
    )
  end

  def test_observation_name_query_rank
    names = Name.with_correct_spelling.rank("Genus", "Kingdom")
    expects = Observation.joins(:name).distinct.
              where(name_id: names).order_by_default
    assert_query(expects,
                 :Observation, name_query: { rank: %w[Genus Kingdom] })
  end

  def test_observation_sequence_query
    sequences = Sequence.locus_has("LSU").by_users(dick)
    expects = Observation.joins(:sequences).distinct.
              merge(sequences).order_by_default
    assert_query(
      expects,
      :Observation, sequence_query: { locus_has: "LSU", by_users: dick.id }
    )
  end
end
