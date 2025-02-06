# frozen_string_literal: true

require("test_helper")

class LookupTest < UnitTestCase
  def assert_lookup_objects_by_name(type, expects, vals, **)
    lookup = "Lookup::#{type}".constantize
    actual = lookup.new(vals, **).titles.sort
    expects = expects.map(&:"#{lookup::TITLE_COLUMN}").sort
    assert_arrays_equal(expects, actual)
  end

  def assert_lookup_names_by_name(expects, vals, **)
    assert_lookup_objects_by_name(:Names, expects, vals, **)
  end

  def test_lookup_external_sites_by_name
    expects = [external_sites(:inaturalist)]
    assert_lookup_objects_by_name(:ExternalSites, expects, "iNaturalist")
  end

  def test_lookup_herbaria_by_name
    expects = [herbaria(:rolf_herbarium), herbaria(:dick_herbarium)]
    assert_lookup_objects_by_name(:Herbaria, expects, expects.map(&:name))
  end

  def test_lookup_herbarium_records_by_name
    expects = [herbarium_records(:coprinus_comatus_nybg_spec),
               herbarium_records(:coprinus_comatus_rolf_spec)]
    assert_lookup_objects_by_name(:HerbariumRecords, expects, expects.map(&:id))
  end

  def test_lookup_locations_by_name
    expects = [locations(:salt_point), locations(:burbank)]
    assert_lookup_objects_by_name(:Locations, expects, expects.map(&:name))
  end

  def test_lookup_projects_by_name
    expects = [projects(:bolete_project)]
    assert_lookup_objects_by_name(:Projects, expects, expects.map(&:title))
  end

  def test_lookup_project_species_lists_by_name
    expects = [species_lists(:unknown_species_list)]
    assert_lookup_objects_by_name(:ProjectSpeciesLists, expects,
                                  "Bolete Project")
  end

  def test_lookup_regions_by_name
    expects = [locations(:point_reyes)]
    assert_lookup_objects_by_name(:Regions, expects,
                                  "Marin Co., California, USA")
  end

  def test_lookup_species_lists_by_name
    expects = [species_lists(:unknown_species_list)]
    assert_lookup_objects_by_name(:SpeciesLists, expects, "List of mysteries")
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

    assert_lookup_names_by_name([name1], ["Macrolepiota"])
    assert_lookup_names_by_name([name2], ["Macrolepiota rachodes"])
    assert_lookup_names_by_name([name1, name4], ["Macrolepiota"],
                                include_synonyms: true)
    assert_lookup_names_by_name([name2, name3, name5],
                                ["Macrolepiota rachodes"],
                                include_synonyms: true)
    assert_lookup_names_by_name([name3, name5],
                                ["Macrolepiota rachodes"],
                                include_synonyms: true,
                                exclude_original_names: true)
    assert_lookup_names_by_name([name1, name2, name3],
                                ["Macrolepiota"],
                                include_subtaxa: true)
    assert_lookup_names_by_name([name1, name2, name3],
                                ["Macrolepiota"],
                                include_immediate_subtaxa: true)
    assert_lookup_names_by_name([name1, name2, name3, name4, name5],
                                ["Macrolepiota"],
                                include_synonyms: true,
                                include_subtaxa: true)
    assert_lookup_names_by_name([name2, name3, name4, name5],
                                ["Macrolepiota"],
                                include_synonyms: true,
                                include_subtaxa: true,
                                exclude_original_names: true)

    name5.update(synonym_id: nil)
    name5 = Name.where(text_name: "Pseudolepiota rachodes").index_order.first
    assert_lookup_names_by_name([name1, name2, name3, name4, name5],
                                ["Macrolepiota"],
                                include_synonyms: true,
                                include_subtaxa: true)
  end

  def test_lookup_names_by_id
    User.current = rolf

    name1 = names(:coprinus_comatus)
    name2 = names(:coprinus_sensu_lato)
    assert_lookup_names_by_name([name1, name2],
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

    assert_lookup_names_by_name([name2, name3], ["Peltigera"])
    assert_lookup_names_by_name([name2, name3], ["Petigera"])
    assert_lookup_names_by_name([name1, name2, name3, name4, name5, name6,
                                 name7],
                                ["Peltigeraceae"],
                                include_subtaxa: true)
    assert_lookup_names_by_name([name1, name2, name3],
                                ["Peltigeraceae"],
                                include_immediate_subtaxa: true)
    assert_lookup_names_by_name([name2, name3, name4, name5, name6, name7],
                                ["Peltigera"],
                                include_subtaxa: true)
    assert_lookup_names_by_name([name2, name3, name4, name6],
                                ["Peltigera"],
                                include_immediate_subtaxa: true)
    assert_lookup_names_by_name([name6, name7],
                                ["Peltigera subg. Foo"],
                                include_immediate_subtaxa: true)
    assert_lookup_names_by_name([name4, name5],
                                ["Peltigera canina"],
                                include_immediate_subtaxa: true)
  end

  def test_lookup_names_by_name_invalid_classification
    User.current = rolf

    name1 = names(:lactarius)
    name2 = create_test_name("Lactarius \"fakename\"")
    name2.update(classification: name1.classification)
    name2.save

    children = Name.index_order.where(Name[:text_name].matches("Lactarius %"))

    assert_lookup_names_by_name([name1] + children,
                                ["Lactarius"],
                                include_subtaxa: true)

    assert_lookup_names_by_name(children,
                                ["Lactarius"],
                                include_immediate_subtaxa: true,
                                exclude_original_names: true)
  end

  def test_lookup_names_by_name_invalid
    assert_lookup_names_by_name([], ["¡not a name!"])
  end

  def create_test_name(name)
    name = Name.new_name(Name.parse_name(name).params)
    name.save
    name
  end
end
