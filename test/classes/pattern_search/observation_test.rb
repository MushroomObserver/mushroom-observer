# frozen_string_literal: true

require("test_helper")

class PatternSearch::ObservationTest < UnitTestCase
  def test_observation_search_name_hack
    # "Turkey" is not a name, and no taxa modifiers present, so no reason to
    # suspect that this is a name query.  Should leave it completely alone.
    x = PatternSearch::Observation.new("Turkey")
    assert_equal({ pattern: "Turkey" }, x.args)

    # "Agaricus" is a name, so let's assume this is a name query.  Note that
    # it will include synonyms and subtaxa by default.
    x = PatternSearch::Observation.new("Agaricus")
    assert_equal({ names: { lookup: "Agaricus", include_subtaxa: true,
                            include_synonyms: true } }, x.args)

    # "Turkey" is not a name, true, but user asked for synonyms to be included,
    # so they must have expected "Turkey" to be a name.  Note that it will also
    # include subtaxa by default, because that behavior was not specified.
    x = PatternSearch::Observation.new("Turkey include_synonyms:yes")
    assert_equal({ names: { lookup: "Turkey", include_synonyms: true,
                            include_subtaxa: true } }, x.args)

    # Just make sure the user is allowed to explicitly turn off synonyms and
    # subtaxa in any names query.
    x = PatternSearch::Observation.new("Foo bar include_synonyms:no " \
                                       "include_subtaxa:no")
    assert_equal({ names: { lookup: "Foo bar", include_synonyms: false,
                            include_subtaxa: false } }, x.args)
  end

  def test_observation_search_for_old_provisional
    x = PatternSearch::Observation.new('Cortinarius "sp-IN34"')
    assert_obj_arrays_equal([observations(:provisional_obs)],
                            x.query.results, :sort)
  end

  def test_observation_search
    x = PatternSearch::Observation.new("Amanita")
    assert_obj_arrays_equal([], x.query.results)

    x = PatternSearch::Observation.new("Agaricus")
    assert_obj_arrays_equal(
      [observations(:agaricus_campestris_obs),
       observations(:agaricus_campestrus_obs),
       observations(:agaricus_campestras_obs),
       observations(:agaricus_campestros_obs)],
      x.query.results, :sort
    )

    x = PatternSearch::Observation.new("Agaricus user:dick")
    assert_obj_arrays_equal([], x.query.results)
    albion = locations(:albion)
    agaricus = names(:agaricus)
    o1 = Observation.create!(when: Date.parse("10/01/2012"),
                             location: albion, name: agaricus, user: dick,
                             specimen: true)
    o2 = Observation.create!(when: Date.parse("30/12/2013"),
                             location: albion, name: agaricus, user: dick,
                             specimen: false)
    assert_equal(20_120_110,
                 o1.when.year * 10_000 + o1.when.month * 100 + o1.when.day)
    assert_equal(20_131_230,
                 o2.when.year * 10_000 + o2.when.month * 100 + o2.when.day)
    x = PatternSearch::Observation.new("Agaricus user:dick")
    assert_obj_arrays_equal([o1, o2], x.query.results, :sort)
    x = PatternSearch::Observation.new("Agaricus user:dick has_specimen:yes")
    assert_obj_arrays_equal([o1], x.query.results)
    x = PatternSearch::Observation.new("Agaricus user:dick has_specimen:no")
    assert_obj_arrays_equal([o2], x.query.results)
    x = PatternSearch::Observation.new("Agaricus date:2013")
    assert_obj_arrays_equal([o2], x.query.results)
    x = PatternSearch::Observation.new("Agaricus date:1")
    assert_obj_arrays_equal([o1], x.query.results)
    x = PatternSearch::Observation.new("Agaricus date:12-01")
    assert_obj_arrays_equal([o1, o2], x.query.results, :sort)
    x = PatternSearch::Observation.new("Agaricus burbank date:2007-03")
    assert_obj_arrays_equal([observations(:agaricus_campestris_obs)],
                            x.query.results)
    x = PatternSearch::Observation.new("Agaricus albion")
    assert_obj_arrays_equal([o1, o2], x.query.results, :sort)
    x = PatternSearch::Observation.new(
      "Agaricus albion user:dick date:2001-2014"
    )
    assert_obj_arrays_equal([o1, o2], x.query.results, :sort)
    x = PatternSearch::Observation.new(
      "Agaricus albion user:dick date:2001-2014 has_specimen:true"
    )
    assert_obj_arrays_equal([o1], x.query.results)
  end

  def test_observation_search_date
    expect = Observation.where(Observation[:when].year.eq(2006))
    assert(expect.any?)
    x = PatternSearch::Observation.new("date:2006")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_created
    expect = Observation.where(Observation[:created_at].year.eq(2010))
    assert(expect.any?)
    x = PatternSearch::Observation.new("created:2010")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_modified
    expect = Observation.where(Observation[:updated_at].year.eq(2013))
    assert(expect.any?)
    x = PatternSearch::Observation.new("modified:2013")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_name
    expect = Observation.where(name: names(:conocybe_filaris)) +
             Observation.where(name: names(:boletus_edulis))
    assert(expect.any?)
    x = PatternSearch::Observation.new(
      'name:"Conocybe filaris","Boletus edulis Bull."'
    )
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_include_synonyms
    expect = Observation.names(lookup: [names(:peltigera), names(:petigera)])
    assert(expect.any?)
    x = PatternSearch::Observation.new("Petigera include_synonyms:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_include_subtaxa
    expect = Observation.names(lookup: names(:agaricus), include_subtaxa: true)
    assert(expect.any?)
    x = PatternSearch::Observation.new("Agaricus include_subtaxa:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_include_all_name_proposals
    expect = Observation.names(lookup: names(:agaricus_campestris),
                               include_all_name_proposals: true)
    consensus = Observation.where(name: name)
    assert(consensus.count < expect.count)
    x = PatternSearch::Observation.new("Agaricus campestris " \
                                       "include_all_name_proposals:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_locations
    expect = Observation.within_locations(locations(:burbank))
    assert(expect.any?)
    x = PatternSearch::Observation.new('location:"USA, California, Burbank"')
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_projects
    expect = Observation.projects(projects(:bolete_project))
    assert(expect.any?)
    x = PatternSearch::Observation.new('project:"Bolete Project"')
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_project_lists
    expect = Observation.project_lists(projects(:bolete_project))
    assert(expect.any?)
    x = PatternSearch::Observation.new('project_lists:"Bolete Project"')
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_species_lists
    expect = Observation.species_lists(species_lists(:unknown_species_list))
    assert(expect.any?)
    x = PatternSearch::Observation.new('list:"List of mysteries"')
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_notes
    expect = Observation.notes_has("somewhere else")
    assert(expect.any?)
    x = PatternSearch::Observation.new('notes:"somewhere else"')
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_comments
    expect = Observation.comments_has("complicated")
    assert(expect.any?)
    x = PatternSearch::Observation.new("comments:complicated")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_field_slip
    code_val = field_slips(:field_slip_one).code
    expect = Observation.field_slips(code_val)
    assert(expect.any?)
    x = PatternSearch::Observation.new("field_slip:#{code_val}")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_confidence
    expect = Observation.confidence(3)
    assert(expect.any?)
    x = PatternSearch::Observation.new("confidence:90")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_in_box
    expect = Observation.where(lat: 34.1622, lng: -118.3521)
    assert(expect.any?)
    x = PatternSearch::Observation.new(
      "west:-118.4 east:-118.3 north:34.2 south:34.1"
    )
    assert_obj_arrays_equal(expect, x.query.results, :sort)

    # missing value
    y = PatternSearch::Observation.new(
      "west:-118.4 east:-118.3 north:34.2"
    )
    assert_raises(PatternSearch::MissingValueError) { y.build_query }

    # north/south inverted, but fixed by build_query
    z = PatternSearch::Observation.new(
      "west:-118.4 east:-118.3 north:34.1 south:34.2"
    )
    assert_obj_arrays_equal(expect, z.query.results, :sort)
  end

  def test_observation_search_has_images_no
    expect = Observation.has_images(false)
    assert(expect.any?)
    x = PatternSearch::Observation.new("has_images:no")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_has_images_yes
    expect = Observation.has_images(true)
    assert(expect.any?)
    x = PatternSearch::Observation.new("has_images:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_has_specimen_no
    expect = Observation.has_specimen(false)
    assert(expect.any?)
    x = PatternSearch::Observation.new("has_specimen:no")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_has_specimen_yes
    expect = Observation.has_specimen
    assert(expect.any?)
    x = PatternSearch::Observation.new("has_specimen:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_has_sequence
    expect = Observation.has_sequences
    assert(expect.any?)
    x = PatternSearch::Observation.new("has_sequence:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  # 2024-04-16 temporary: test that we suggest new terms for retired terms.
  def test_observation_search_bad_term_suggestions
    x = PatternSearch::Observation.new("images:true")
    assert_equal(
      :pattern_search_bad_term_error_suggestion.tp(
        term: "images", val: "true", new_term: "has_images"
      ).to_s.as_displayed,
      x.errors[0].to_s.t.as_displayed
    )
    y = PatternSearch::Observation.new("sequence:true")
    assert_equal(
      :pattern_search_bad_term_error_suggestion.tp(
        term: "sequence", val: "true", new_term: "has_sequence"
      ).to_s.as_displayed,
      y.errors[0].to_s.t.as_displayed
    )
    z = PatternSearch::Observation.new("specimen:true")
    assert_equal(
      :pattern_search_bad_term_error_suggestion.tp(
        term: "specimen", val: "true", new_term: "has_specimen"
      ).to_s.as_displayed,
      z.errors[0].to_s.t.as_displayed
    )
  end

  def test_observation_search_has_name_no
    expect = Observation.has_name(false)
    assert(expect.any?)
    x = PatternSearch::Observation.new("has_name:no")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_has_name_yes
    expect = Observation.has_name
    assert(expect.any?)
    x = PatternSearch::Observation.new("has_name:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_has_notes_no
    expect = Observation.has_notes(false)
    assert(expect.any?)
    x = PatternSearch::Observation.new("has_notes:no")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_has_notes_yes
    expect = Observation.has_notes
    assert(expect.any?)
    x = PatternSearch::Observation.new("has_notes:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_has_comments_yes
    expect = Observation.has_comments
    assert(expect.any?)
    x = PatternSearch::Observation.new("has_comments:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_herbarium
    expect = Observation.herbaria(herbaria(:nybg_herbarium))
    assert_not_empty(expect)
    x = PatternSearch::Observation.new(
      'herbarium:"The New York Botanical Garden"'
    )
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_region
    expect = Observation.region("California, USA")
    cal = locations(:california).observations.first
    assert_not_nil(cal)
    assert_includes(expect, cal)
    x = PatternSearch::Observation.new('region:"USA, California"')
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_multiple_regions
    expect = Observation.region(["California, USA", "New York, USA"]).
             reorder(id: :asc).to_a
    assert(expect.any? { |obs| obs.where.include?("California, USA") })
    assert(expect.any? { |obs| obs.where.include?("New York, USA") })
    str = 'region:"USA, California","USA, New York"'
    x = PatternSearch::Observation.new(str)
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end

  def test_observation_search_lichen
    expect = Observation.lichen(true)
    assert_not_empty(expect)
    x = PatternSearch::Observation.new("lichen:yes")
    assert_obj_arrays_equal(expect, x.query.results, :sort)

    expect = Observation.lichen(false)
    assert_not_empty(expect)
    x = PatternSearch::Observation.new("lichen:false")
    assert_obj_arrays_equal(expect, x.query.results, :sort)
  end
end
