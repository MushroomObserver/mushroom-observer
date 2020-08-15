# frozen_string_literal: true

require "test_helper"

class NameSorterTest < UnitTestCase
  def test_add_name_default
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name("Foo bar")
    assert_equal(["Foo bar"], name_sorter.new_name_strs)
    assert_equal(["Foo bar"], name_sorter.new_line_strs)
    assert_equal([], name_sorter.all_names)
  end

  def test_add_name_coprinus_comatus
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name(names(:coprinus_comatus).text_name)
    assert_equal([], name_sorter.new_name_strs)
    assert_equal([], name_sorter.new_line_strs)
    assert_equal([names(:coprinus_comatus)], name_sorter.all_names)
  end

  def test_add_name_explicit
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name("Species Foo bar")
    assert_equal(["Foo bar"], name_sorter.new_name_strs)
    assert_equal(["Species Foo bar"], name_sorter.new_line_strs)
    assert_equal([], name_sorter.all_names)
  end

  def test_add_name_genus
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name("Genus Foobar")
    assert_equal(["Foobar"], name_sorter.new_name_strs)
    assert_equal(["Genus Foobar"], name_sorter.new_line_strs)
    assert_equal([], name_sorter.all_names)
  end

  def test_add_name_genus_psalliota
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name(
      "#{names(:psalliota).rank} #{names(:psalliota).text_name}"
    )
    assert_equal([], name_sorter.new_name_strs)
    assert_equal([], name_sorter.new_line_strs)
    assert_equal([names(:psalliota)], name_sorter.all_names)
  end

  def test_add_name_default_synonym_lepiota
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name(
      "#{names(:macrolepiota_rachodes).text_name} = " \
      "#{names(:lepiota_rachodes).text_name}"
    )
    assert_equal([], name_sorter.new_name_strs)
    assert_equal([], name_sorter.new_line_strs)
    assert_equal([names(:macrolepiota_rachodes)], name_sorter.all_names)
    assert_equal([names(:lepiota_rachodes)],
                 name_sorter.synonym_data[0][0].find_synonym_names)
  end

  def test_add_name_default_synonym
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name("Foo bar = Baz woof")
    assert_equal(["Foo bar", "Baz woof"], name_sorter.new_name_strs)
    assert_equal(["Foo bar = Baz woof"], name_sorter.new_line_strs)
    assert_equal([], name_sorter.all_names)
  end

  def test_add_name_genus_synonym_agaricus
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name(
      "#{names(:agaricus).rank} #{names(:agaricus).text_name} = " \
      "#{names(:psalliota).rank} #{names(:psalliota).text_name}"
    )
    assert_equal([], name_sorter.new_name_strs)
    assert_equal([], name_sorter.new_line_strs)
    assert_equal([names(:agaricus)], name_sorter.all_names)
    assert_equal([names(:psalliota)],
                 name_sorter.synonym_data[0][0].find_synonym_names)
  end

  def test_add_name_genus_synonym
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name("Genus Foobar = Genus Bazwoof")
    assert_equal(%w[Foobar Bazwoof], name_sorter.new_name_strs)
    assert_equal(["Genus Foobar = Genus Bazwoof"], name_sorter.new_line_strs)
    assert_equal([], name_sorter.all_names)
  end

  def test_push_synonym
    sorter = NameSorter.new
    sorter.add_name(names(:namings_deprecated_1).text_name)
    sorter.add_name(names(:namings_deprecated_2).text_name)

    sorter.push_synonym(names(:namings_deprecated).id)
    assert(sorter.approved_synonyms.include?(names(:namings_deprecated)))

    sorter.push_synonym(names(:fungi))
    assert(sorter.approved_synonyms.include?(names(:fungi)))

    assert_raises(TypeError) do
      sorter.push_synonym("A string")
    end
  end
end
