# frozen_string_literal: true

require "test_helper"

class NameParseTest < UnitTestCase
  def test_default
    name_parse = NameParse.new("Foo bar")
    assert_not_nil(name_parse)
    assert_nil(name_parse.rank)
    assert_equal("Foo bar", name_parse.search_name)
    assert_not(name_parse.has_synonym)
    assert_equal([], name_parse.find_names)
    assert_equal([], name_parse.find_synonym_names)
  end

  def test_coprinus_comatus
    name_parse = NameParse.new(names(:coprinus_comatus).text_name)
    assert_not_nil(name_parse)
    assert_nil(name_parse.rank)
    assert_equal(names(:coprinus_comatus).text_name, name_parse.search_name)
    assert_not(name_parse.has_synonym)
    assert_equal([names(:coprinus_comatus)], name_parse.find_names)
    assert_equal([], name_parse.find_synonym_names)
  end

  def test_fungi
    input_str = names(:fungi).text_name
    name_parse = NameParse.new(input_str)
    assert_not_nil(name_parse)
    assert_nil(name_parse.rank)
    assert_equal(names(:fungi).text_name, name_parse.search_name)
    assert_not(name_parse.has_synonym)
    assert_equal([names(:fungi)], name_parse.find_names)
    assert_equal([], name_parse.find_synonym_names)
  end

  def test_explicit
    name_parse = NameParse.new("Species Foo bar")
    assert_not_nil(name_parse)
    assert_equal(:Species, name_parse.rank)
    assert_equal("Foo bar", name_parse.search_name)
    assert_not(name_parse.has_synonym)
    assert_equal([], name_parse.find_names)
    assert_equal([], name_parse.find_synonym_names)
  end

  def test_explicit_coprinus_comatus
    input_str = "#{names(:coprinus_comatus).rank} " \
                "#{names(:coprinus_comatus).text_name}"
    name_parse = NameParse.new(input_str)
    assert_not_nil(name_parse)
    assert_equal(names(:coprinus_comatus).rank.to_sym, name_parse.rank)
    assert_equal(names(:coprinus_comatus).text_name, name_parse.search_name)
    assert_not(name_parse.has_synonym)
    assert_equal([names(:coprinus_comatus)], name_parse.find_names)
    assert_equal([], name_parse.find_synonym_names)
  end

  def test_explicit_fungi
    input_str = "#{names(:fungi).rank} #{names(:fungi).text_name}"
    name_parse = NameParse.new(input_str)
    assert_not_nil(name_parse)
    assert_equal(names(:fungi).rank.to_sym, name_parse.rank)
    assert_equal(names(:fungi).text_name, name_parse.search_name)
    assert_not(name_parse.has_synonym)
    assert_equal([names(:fungi)], name_parse.find_names)
    assert_equal([], name_parse.find_synonym_names)
  end

  def test_explicit_coprinus_comatus_full_name
    input_str = "#{names(:coprinus_comatus).rank} " \
                "#{names(:coprinus_comatus).search_name}"
    name_parse = NameParse.new(input_str)
    assert_not_nil(name_parse)
    assert_equal(names(:coprinus_comatus).rank.to_sym, name_parse.rank)
    assert_equal(names(:coprinus_comatus).search_name, name_parse.search_name)
    assert_not(name_parse.has_synonym)
    assert_equal([names(:coprinus_comatus)], name_parse.find_names)
    assert_equal([], name_parse.find_synonym_names)
  end

  def test_genus
    name_parse = NameParse.new("Genus Foobar")
    assert_not_nil(name_parse)
    assert_equal(:Genus, name_parse.rank)
    assert_equal("Foobar", name_parse.search_name)
    assert_not(name_parse.has_synonym)
    assert_equal([], name_parse.find_names)
    assert_equal([], name_parse.find_synonym_names)
  end

  def test_default_synonym_lepiota
    name_parse = NameParse.new("#{names(:macrolepiota_rachodes).text_name} = " \
                               "#{names(:lepiota_rachodes).text_name}")
    assert_not_nil(name_parse)
    assert_nil(name_parse.rank)
    assert_equal(names(:macrolepiota_rachodes).text_name,
                 name_parse.search_name)
    assert(name_parse.has_synonym)
    assert_nil(name_parse.synonym_rank)
    assert_equal(names(:lepiota_rachodes).text_name,
                 name_parse.synonym_search_name)
    assert_equal([names(:macrolepiota_rachodes)], name_parse.find_names)
    assert_equal([names(:lepiota_rachodes)], name_parse.find_synonym_names)
  end

  def test_default_synonym
    name_parse = NameParse.new("Foo bar = Baz woof")
    assert_not_nil(name_parse)
    assert_nil(name_parse.rank)
    assert_equal("Foo bar", name_parse.search_name)
    assert(name_parse.has_synonym)
    assert_nil(name_parse.synonym_rank)
    assert_equal("Baz woof", name_parse.synonym_search_name)
    assert_equal([], name_parse.find_names)
    assert_equal([], name_parse.find_synonym_names)
  end

  def test_genus_synonym_agaricus
    name_parse = NameParse.new(
      "#{names(:agaricus).rank} #{names(:agaricus).text_name} = " \
      "#{names(:psalliota).rank} #{names(:psalliota).text_name}"
    )
    assert_not_nil(name_parse)
    assert_equal(names(:agaricus).rank.to_sym, name_parse.rank)
    assert_equal(names(:agaricus).text_name, name_parse.search_name)
    assert(name_parse.has_synonym)
    assert_equal(names(:psalliota).rank.to_sym, name_parse.synonym_rank)
    assert_equal(names(:psalliota).text_name, name_parse.synonym_search_name)
    assert_equal([names(:agaricus)], name_parse.find_names)
    assert_equal([names(:psalliota)], name_parse.find_synonym_names)
  end

  def test_genus_synonym
    name_parse = NameParse.new("Genus Foobar = Genus Bazwoof")
    assert_not_nil(name_parse)
    assert_equal(:Genus, name_parse.rank)
    assert_equal("Foobar", name_parse.search_name)
    assert(name_parse.has_synonym)
    assert_equal(:Genus, name_parse.synonym_rank)
    assert_equal("Bazwoof", name_parse.synonym_search_name)
    assert_equal([], name_parse.find_names)
    assert_equal([], name_parse.find_synonym_names)
  end
end
