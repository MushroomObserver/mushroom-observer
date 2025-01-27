# frozen_string_literal: true

require("test_helper")

class LookupTest < UnitTestCase
  # tests of Lookup::Names
  def create_test_name(name)
    name = Name.new_name(Name.parse_name(name).params)
    name.save
    name
  end

  def assert_lookup_names_by_name(expects, vals, params = {})
    actual = Lookup::Names.new(vals, **params).instances.sort_by(&:text_name)
    expects = expects.sort_by(&:text_name)
    # actual = actual.map { |id| Name.find(id) }.sort_by(&:text_name)
    assert_name_arrays_equal(expects, actual)
  end

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

  def test_lookup_names_by_name2
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

  def test_lookup_names_by_name3
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

  def test_lookup_names_by_name4
    assert_lookup_names_by_name([], ["¡not a name!"])
  end
end
