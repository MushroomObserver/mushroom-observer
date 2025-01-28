# frozen_string_literal: true

require("test_helper")

# tests of Query::Observations class to be included in QueryTest
module Query::ObservationsTest
  def test_observation_all
    expects = Observation.index_order
    assert_query(expects, :Observation)
  end

  # Overwrites scope `order_by_rss_log` in abstract_model
  def test_observation_by_rss_log
    expects = Observation.order_by_rss_log
    assert_query(expects, :Observation, by: :rss_log)
  end

  def observations_set
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
    ]
  end

  def test_observation_ids_ids
    assert_query(observations_set.map(&:id),
                 :Observation, ids: observations_set.map(&:id))
  end

  def test_observation_ids_instances
    assert_query(observations_set.map(&:id),
                 :Observation, ids: observations_set)
  end

  def test_observation_by_user
    expects = Observation.reorder(id: :asc).where(user: rolf.id).to_a
    assert_query(expects, :Observation, by_user: rolf, by: :id)
    expects = Observation.reorder(id: :asc).where(user: mary.id).to_a
    assert_query(expects, :Observation, by_user: mary, by: :id)
    expects = Observation.reorder(id: :asc).where(user: dick.id).to_a
    assert_query(expects, :Observation, by_user: dick, by: :id)
    assert_query([], :Observation, by_user: junk, by: :id)
  end

  def test_observation_in_project_list
    project = projects(:bolete_project)
    # expects = project.species_lists.map(&:observations).flatten.to_a
    expects = Observation.index_order.
              joins(species_lists: :project_species_lists).
              where(project_species_lists: { project: project }).distinct
    assert_query(expects, :Observation, project_lists: project.title)
  end

  def test_observation_at_location
    expects = Observation.index_order.
              where(location: locations(:burbank)).distinct
    assert_query(expects, :Observation, location: locations(:burbank))
  end

  def test_observation_for_project
    assert_query([],
                 :Observation, project: projects(:empty_project))
    assert_query(projects(:bolete_project).observations,
                 :Observation, project: projects(:bolete_project))
  end

  def test_observation_for_project_projects_equivalence
    qu1 = Query.lookup_and_save(:Observation,
                                project: projects(:bolete_project))
    qu2 = Query.lookup_and_save(:Observation,
                                projects: projects(:bolete_project).id.to_s)
    assert_equal(qu1.results, qu2.results)
  end

  def test_observation_in_species_list
    # These two are identical, so should be disambiguated by reverse_id.
    assert_query([observations(:detailed_unknown_obs).id,
                  observations(:minimal_unknown_obs).id],
                 :Observation,
                 species_list: species_lists(:unknown_species_list).id)
  end

  def test_observation_of_children
    name = names(:agaricus)
    expects = Observation.index_order.
              of_name(name, include_subtaxa: true).distinct
    assert_query(expects, :Observation, names: [name.id], include_subtaxa: true)
  end

  def test_observation_of_name_with_modifiers
    User.current = rolf
    expects = Observation.index_order.where(name: names(:fungi)).distinct
    assert_query(expects, :Observation, names: [names(:fungi).id])
    assert_query([],
                 :Observation, names: [names(:macrolepiota_rachodes).id])

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
    assert_query([observations(:agaricus_campestris_obs).id],
                 :Observation,
                 names: [names(:agaricus_campestris).id],
                 include_synonyms: false,
                 include_all_name_proposals: false,
                 exclude_consensus: false)

    # name(s) is consensus, but is not the consensus (an oxymoron)
    assert_query([],
                 :Observation,
                 names: [names(:agaricus_campestris).id],
                 include_synonyms: false,
                 include_all_name_proposals: false,
                 exclude_consensus: true)

    # name(s) is proposed
    assert_query([observations(:agaricus_campestris_obs).id,
                  observations(:coprinus_comatus_obs).id],
                 :Observation,
                 names: [names(:agaricus_campestris).id],
                 include_synonyms: false,
                 include_all_name_proposals: true,
                 exclude_consensus: false)

    # name(s) is proposed, but is not the consensus
    assert_query([observations(:coprinus_comatus_obs).id],
                 :Observation,
                 names: [names(:agaricus_campestris).id],
                 include_synonyms: false,
                 include_all_name_proposals: true,
                 exclude_consensus: true)

    # consensus is a synonym of name(s)
    assert_query([observations(:agaricus_campestros_obs).id,
                  observations(:agaricus_campestras_obs).id,
                  observations(:agaricus_campestrus_obs).id,
                  observations(:agaricus_campestris_obs).id],
                 :Observation,
                 names: [names(:agaricus_campestris).id],
                 include_synonyms: true,
                 include_all_name_proposals: false,
                 exclude_consensus: false)

    # same as above but exclude_original_names
    # conensus is a synonym of name(s) other than name(s)
    assert_query([observations(:agaricus_campestros_obs).id,
                  observations(:agaricus_campestras_obs).id,
                  observations(:agaricus_campestrus_obs).id],
                 :Observation,
                 names: [names(:agaricus_campestris).id],
                 include_synonyms: true,
                 exclude_original_names: true)

    # consensus is a synonym of name(s) but not a synonym of name(s) (oxymoron)
    assert_query([],
                 :Observation,
                 names: [names(:agaricus_campestras).id],
                 include_synonyms: true,
                 include_all_name_proposals: false,
                 exclude_consensus: true)

    # where synonyms of names are proposed
    assert_query([observations(:agaricus_campestros_obs).id,
                  observations(:agaricus_campestras_obs).id,
                  observations(:agaricus_campestrus_obs).id,
                  observations(:agaricus_campestris_obs).id,
                  observations(:coprinus_comatus_obs).id],
                 :Observation,
                 names: [names(:agaricus_campestris).id],
                 include_synonyms: true,
                 include_all_name_proposals: true,
                 exclude_consensus: false)

    # where synonyms of name are proposed, but are not the consensus
    assert_query([observations(:coprinus_comatus_obs).id],
                 :Observation,
                 names: [names(:agaricus_campestras).id],
                 include_synonyms: true,
                 include_all_name_proposals: true,
                 exclude_consensus: true)

    spl = species_lists(:first_species_list)
    spl.observations << observations(:agaricus_campestrus_obs)
    spl.observations << observations(:agaricus_campestros_obs)
    proj = projects(:eol_project)
    proj.observations << observations(:agaricus_campestris_obs)
    proj.observations << observations(:agaricus_campestras_obs)

    assert_query([observations(:agaricus_campestros_obs).id,
                  observations(:agaricus_campestrus_obs).id],
                 :Observation,
                 names: agaricus_ssp.map(&:text_name),
                 species_lists: [spl.title])

    assert_query([observations(:agaricus_campestras_obs).id,
                  observations(:agaricus_campestris_obs).id],
                 :Observation,
                 names: agaricus_ssp.map(&:text_name),
                 projects: [proj.title])
  end

  # notes search disabled because it may mention other species. confusing
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
    Observation.index_order.pattern_search(pattern).distinct
  end

  def test_observation_advanced_search_name
    assert_query([observations(:strobilurus_diminutivus_obs).id],
                 :Observation, name: "diminutivus")
  end

  def test_observation_advanced_search_where
    assert_query([observations(:coprinus_comatus_obs).id],
                 :Observation, user_where: "glendale") # where
    expects = Observation.reorder(id: :asc).
              where(location: locations(:burbank)).distinct
    assert_query(expects, :Observation,
                 user_where: "burbank", by: :id) # location
  end

  def test_observation_advanced_search_user
    expects = Observation.reorder(id: :asc).where(user: rolf.id).distinct
    assert_query(expects, :Observation, user: "rolf", by: :id)
  end

  def test_observation_advanced_search_content
    assert_query(Observation.advanced_search("second fruiting"),
                 :Observation, content: "second fruiting") # notes
    assert_query(Observation.advanced_search("agaricus"),
                 :Observation, content: "agaricus") # comment
  end

  def test_observation_date
    # blank should return all
    assert_query(Observation.index_order, :Observation, date: nil)
    # impossible dates should return none
    assert_query([], :Observation, date: %w[1550 1551])
    # single date should return after
    assert_query(Observation.index_order.when_after("2011-05-12"),
                 :Observation, date: "2011-05-12")
    # year should return after
    assert_query(Observation.index_order.when_after("2005"),
                 :Observation, date: "2005")
    # years should return between
    assert_query(Observation.index_order.when_between("2005", "2009"),
                 :Observation, date: %w[2005 2009])
    # in a month range, any year
    assert_query(Observation.index_order.when_between("05", "12"),
                 :Observation, date: %w[05 12])
    # in a date range, any year
    assert_query(Observation.index_order.when_between("02-22", "08-22"),
                 :Observation, date: %w[02-22 08-22])
    # period wraps around the new year
    assert_query(Observation.index_order.when_between("08-22", "02-22"),
                 :Observation, date: %w[08-22 02-22])
    # full dates
    assert_query(Observation.index_order.
                 when_between("2009-08-22", "2009-10-20"),
                 :Observation, date: %w[2009-08-22 2009-10-20])
    # date wraps around the new year
    assert_query(Observation.index_order.
                 when_between("2015-08-22", "2016-02-22"),
                 :Observation, date: %w[2015-08-22 2016-02-22])
  end

  def test_observation_created_at
    # blank should return all
    assert_query(Observation.index_order, :Observation, created_at: nil)
    # impossible dates should return none
    assert_query([], :Observation, created_at: %w[2000 2001])
    # single datetime should return after
    assert_query(Observation.index_order.
                 created_after("2011-05-12-12-59-57"),
                 :Observation, created_at: "2011-05-12-12-59-57")
    # single date should return after
    assert_query(Observation.index_order.created_after("2011-05-12"),
                 :Observation, created_at: "2011-05-12")
    # year should return after
    assert_query(Observation.index_order.created_after("2005"),
                 :Observation, created_at: "2005")
    # years should return between
    assert_query(Observation.index_order.created_between("2005", "2009"),
                 :Observation, created_at: %w[2005 2009])
    # full dates
    assert_query(Observation.index_order.
                 created_between("2009-08-22", "2009-10-20"),
                 :Observation, created_at: %w[2009-08-22 2009-10-20])
    # full datetimes
    assert_query(Observation.index_order.
                 created_between("2009-08-22-03-04-22", "2009-10-20-03-04-22"),
                 :Observation,
                 created_at: %w[2009-08-22-03-04-22 2009-10-20-03-04-22])
  end

  def test_observation_updated_at
    # blank should return all
    assert_query(Observation.index_order, :Observation, updated_at: nil)
    # impossible dates should return none
    assert_query([], :Observation, updated_at: %w[2000 2001])
    # single datetime should return after
    assert_query(Observation.index_order.
                 updated_after("2011-05-12-12-59-57"),
                 :Observation, updated_at: "2011-05-12-12-59-57")
    # single date should return after
    assert_query(Observation.index_order.updated_after("2011-05-12"),
                 :Observation, updated_at: "2011-05-12")
    # year should return after
    assert_query(Observation.index_order.updated_after("2005"),
                 :Observation, updated_at: "2005")
    # years should return between
    assert_query(Observation.index_order.updated_between("2005", "2009"),
                 :Observation, updated_at: %w[2005 2009])
    # full dates
    assert_query(Observation.index_order.
                 updated_between("2009-08-22", "2009-10-20"),
                 :Observation, updated_at: %w[2009-08-22 2009-10-20])
    # full datetimes
    assert_query(Observation.index_order.
                 updated_between("2009-08-22-03-04-22", "2009-10-20-03-04-22"),
                 :Observation,
                 updated_at: %w[2009-08-22-03-04-22 2009-10-20-03-04-22])
  end
end
