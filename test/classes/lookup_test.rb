# frozen_string_literal: true

require("test_helper")

class LookupTest < UnitTestCase
  def assert_lookup_objects(type, expects, vals, **)
    lookup = "Lookup::#{type}".constantize
    actual = lookup.new(vals, **).titles.sort
    expects = expects.map(&:"#{lookup::TITLE_METHOD}").sort
    assert_arrays_equal(expects, actual)
  end

  def assert_lookup_names(expects, vals, **)
    assert_lookup_objects(:Names, expects, vals, **)
  end

  def test_lookup_external_sites_by_name
    expects = [external_sites(:inaturalist)]
    assert_lookup_objects(:ExternalSites, expects, "iNaturalist")
  end

  def test_lookup_herbaria_by_name
    expects = [herbaria(:rolf_herbarium), herbaria(:dick_herbarium)]
    assert_lookup_objects(:Herbaria, expects, expects.map(&:name))
  end

  def test_lookup_herbarium_records_by_name
    expects = [herbarium_records(:coprinus_comatus_nybg_spec),
               herbarium_records(:coprinus_comatus_rolf_spec)]
    assert_lookup_objects(:HerbariumRecords, expects, expects.map(&:id))
  end

  def test_lookup_locations_by_name
    expects = [locations(:salt_point), locations(:burbank)]
    assert_lookup_objects(:Locations, expects, expects.map(&:name))
  end

  def test_lookup_projects_by_name
    expects = [projects(:bolete_project)]
    assert_lookup_objects(:Projects, expects, expects.map(&:title))
  end

  def test_lookup_project_species_lists_by_name
    expects = [species_lists(:unknown_species_list)]
    assert_lookup_objects(:ProjectSpeciesLists, expects, "Bolete Project")
  end

  def test_lookup_regions_by_name
    expects = [locations(:point_reyes)]
    assert_lookup_objects(:Regions, expects, "Marin Co., California, USA")
  end

  def test_lookup_species_lists_by_name
    expects = [species_lists(:unknown_species_list)]
    assert_lookup_objects(:SpeciesLists, expects, "List of mysteries")
  end

  def test_lookup_observation_titles_by_id
    expects = Observation.take(6)
    assert_lookup_objects(:Observations, expects, expects.map(&:id))
  end

  ########################################################################
  # tests of Lookup::Names
  #
  def test_lookup_names_by_name
    User.current = rolf

    name1 = names(:macrolepiota)
    name2 = names(:macrolepiota_rachodes)
    name3 = names(:macrolepiota_rhacodes)
    name4 = create_test_name("Pseudolepiota")
    name5 = create_test_name("Pseudolepiota rachodes")

    name1.update(synonym_id: Synonym.create.id)
    name4.update(synonym_id: name1.synonym_id)
    name5.update(synonym_id: name2.synonym_id)

    assert_lookup_names([name1], ["Macrolepiota"])
    assert_lookup_names([name2], ["Macrolepiota rachodes"])
    assert_lookup_names([name1, name4], ["Macrolepiota"],
                        include_synonyms: true)
    assert_lookup_names([name2, name3, name5],
                        ["Macrolepiota rachodes"],
                        include_synonyms: true)
    assert_lookup_names([name3, name5],
                        ["Macrolepiota rachodes"],
                        include_synonyms: "yes", # test boolean
                        exclude_original_names: "yes")
    assert_lookup_names([name1, name2, name3],
                        ["Macrolepiota"],
                        include_subtaxa: true)
    assert_lookup_names([name1, name2, name3],
                        ["Macrolepiota"],
                        include_immediate_subtaxa: true)
    assert_lookup_names([name4, name5],
                        ["Macrolepiota"],
                        include_synonyms: true,
                        include_subtaxa: true,
                        exclude_original_names: true)
    assert_lookup_names([name1, name2, name3, name4, name5],
                        ["Macrolepiota"],
                        include_synonyms: 1, # test boolean
                        include_subtaxa: 1)

    name5.update(synonym_id: nil)
    name5 = Name.where(text_name: "Pseudolepiota rachodes").
            order_by_default.first
    assert_lookup_names([name1, name2, name3, name4, name5],
                        ["Macrolepiota"],
                        include_synonyms: true,
                        include_subtaxa: true)
  end

  def test_lookup_names_by_id
    User.current = rolf

    name1 = names(:coprinus_comatus)
    name2 = names(:coprinus_sensu_lato)
    assert_lookup_names([name1, name2],
                        [name1.text_name, name2.id.to_s])
  end

  def test_lookup_names_by_name_classifications
    User.current = rolf

    name1 = names(:peltigeraceae)
    name2 = names(:peltigera)
    name3 = names(:petigera)
    name4 = create_test_name("Peltigera canina")
    name5 = create_test_name("Peltigera canina var. spuria")
    name6 = create_test_name("Peltigera subg. Foo")
    name7 = create_test_name("Peltigera subg. Foo sect. Bar")

    name4.update(classification: name2.classification)
    name5.update(classification: name2.classification)
    name6.update(classification: name2.classification)
    name7.update(classification: name2.classification)

    assert_lookup_names([name2], ["Peltigera"])
    assert_lookup_names([name3], ["Petigera"])
    assert_lookup_names([name1, name2, name4, name5, name6, name7],
                        ["Peltigeraceae"],
                        include_subtaxa: true)
    assert_lookup_names([name1, name2, name3, name4, name5, name6, name7],
                        ["Peltigeraceae"],
                        include_subtaxa: true,
                        include_synonyms: true)
    assert_lookup_names([name1, name2],
                        ["Peltigeraceae"],
                        include_immediate_subtaxa: true)
    assert_lookup_names([name1, name2, name4, name5, name6, name7],
                        ["Peltigera"],
                        include_subtaxa: true)
    assert_lookup_names([name2, name4, name6],
                        ["Peltigera"],
                        include_immediate_subtaxa: true)
    assert_lookup_names([name6, name7],
                        ["Peltigera subg. Foo"],
                        include_immediate_subtaxa: true)
    assert_lookup_names([name4, name5],
                        ["Peltigera canina"],
                        include_immediate_subtaxa: true)
  end

  def test_lookup_names_by_name_invalid_classification
    User.current = rolf

    name1 = names(:lactarius)
    name2 = create_test_name("Lactarius \"fakename\"")
    name2.update(classification: name1.classification)
    name2.save

    children = Name.order_by_default.
               where(Name[:text_name].matches("Lactarius %"))

    assert_lookup_names([name1] + children,
                        ["Lactarius"],
                        include_subtaxa: true)

    assert_lookup_names(children,
                        ["Lactarius"],
                        include_immediate_subtaxa: true,
                        exclude_original_names: true)
  end

  def test_lookup_names_by_name_invalid
    assert_lookup_names([], ["¡not a name!"])
  end

  def create_test_name(name)
    params = Name.parse_name(name).params
    params[:user] ||= rolf
    name = Name.new_name(params)
    name.save
    name
  end
end
