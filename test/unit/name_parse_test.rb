require File.dirname(__FILE__) + '/../boot'

class NameParseTest < Test::Unit::TestCase
  fixtures :names

  def test_default
    name_parse = NameParse.new('Foo bar')
    assert_not_nil(name_parse)
    assert_nil(name_parse.rank)
    assert_equal('Foo bar', name_parse.search_name)
    assert(!name_parse.has_synonym())
    assert_equal([], name_parse.find_names())
    assert_equal([], name_parse.find_synonym_names())
  end

  def test_coprinus_comatus
    name_parse = NameParse.new(@coprinus_comatus.text_name)
    assert_not_nil(name_parse)
    assert_nil(name_parse.rank)
    assert_equal(@coprinus_comatus.text_name, name_parse.search_name)
    assert(!name_parse.has_synonym())
    assert_equal([@coprinus_comatus], name_parse.find_names())
    assert_equal([], name_parse.find_synonym_names())
  end

  def test_fungi
    input_str = @fungi.text_name
    name_parse = NameParse.new(input_str)
    assert_not_nil(name_parse)
    assert_nil(name_parse.rank)
    assert_equal(@fungi.text_name, name_parse.search_name)
    assert(!name_parse.has_synonym())
    assert_equal([@fungi], name_parse.find_names())
    assert_equal([], name_parse.find_synonym_names())
  end

  def test_explicit
    name_parse = NameParse.new('Species Foo bar')
    assert_not_nil(name_parse)
    assert_equal(:Species, name_parse.rank)
    assert_equal('Foo bar', name_parse.search_name)
    assert(!name_parse.has_synonym())
    assert_equal([], name_parse.find_names())
    assert_equal([], name_parse.find_synonym_names())
  end

  def test_explicit_coprinus_comatus
    input_str = "#{@coprinus_comatus.rank} #{@coprinus_comatus.text_name}"
    name_parse = NameParse.new(input_str)
    assert_not_nil(name_parse)
    assert_equal(@coprinus_comatus.rank, name_parse.rank)
    assert_equal(@coprinus_comatus.text_name, name_parse.search_name)
    assert(!name_parse.has_synonym())
    assert_equal([@coprinus_comatus], name_parse.find_names())
    assert_equal([], name_parse.find_synonym_names())
  end

  def test_explicit_fungi
    input_str = "#{@fungi.rank} #{@fungi.text_name}"
    name_parse = NameParse.new(input_str)
    assert_not_nil(name_parse)
    assert_equal(@fungi.rank, name_parse.rank)
    assert_equal(@fungi.text_name, name_parse.search_name)
    assert(!name_parse.has_synonym())
    assert_equal([@fungi], name_parse.find_names())
    assert_equal([], name_parse.find_synonym_names())
  end

  def test_explicit_coprinus_comatus_full_name
    input_str = "#{@coprinus_comatus.rank} #{@coprinus_comatus.search_name}"
    name_parse = NameParse.new(input_str)
    assert_not_nil(name_parse)
    assert_equal(@coprinus_comatus.rank, name_parse.rank)
    assert_equal(@coprinus_comatus.search_name, name_parse.search_name)
    assert(!name_parse.has_synonym())
    assert_equal([@coprinus_comatus], name_parse.find_names())
    assert_equal([], name_parse.find_synonym_names())
  end

  def test_genus
    name_parse = NameParse.new('Genus Foobar')
    assert_not_nil(name_parse)
    assert_equal(:Genus, name_parse.rank)
    assert_equal('Foobar', name_parse.search_name)
    assert(!name_parse.has_synonym())
    assert_equal([], name_parse.find_names())
    assert_equal([], name_parse.find_synonym_names())
  end

  def test_default_synonym_lepiota
    name_parse = NameParse.new("#{@macrolepiota_rachodes.text_name} = #{@lepiota_rachodes.text_name}")
    assert_not_nil(name_parse)
    assert_nil(name_parse.rank)
    assert_equal(@macrolepiota_rachodes.text_name, name_parse.search_name)
    assert(name_parse.has_synonym())
    assert_nil(name_parse.synonym_rank)
    assert_equal(@lepiota_rachodes.text_name, name_parse.synonym_search_name)
    assert_equal([@macrolepiota_rachodes], name_parse.find_names())
    assert_equal([@lepiota_rachodes], name_parse.find_synonym_names())
  end

  def test_default_synonym
    name_parse = NameParse.new('Foo bar = Baz woof')
    assert_not_nil(name_parse)
    assert_nil(name_parse.rank)
    assert_equal('Foo bar', name_parse.search_name)
    assert(name_parse.has_synonym())
    assert_nil(name_parse.synonym_rank)
    assert_equal('Baz woof', name_parse.synonym_search_name)
    assert_equal([], name_parse.find_names())
    assert_equal([], name_parse.find_synonym_names())
  end

  def test_genus_synonym_agaricus
    name_parse = NameParse.new("#{@agaricus.rank} #{@agaricus.text_name} = #{@psalliota.rank} #{@psalliota.text_name}")
    assert_not_nil(name_parse)
    assert_equal(@agaricus.rank, name_parse.rank)
    assert_equal(@agaricus.text_name, name_parse.search_name)
    assert(name_parse.has_synonym())
    assert_equal(@psalliota.rank, name_parse.synonym_rank)
    assert_equal(@psalliota.text_name, name_parse.synonym_search_name)
    assert_equal([@agaricus], name_parse.find_names())
    assert_equal([@psalliota], name_parse.find_synonym_names())
  end

  def test_genus_synonym
    name_parse = NameParse.new('Genus Foobar = Genus Bazwoof')
    assert_not_nil(name_parse)
    assert_equal(:Genus, name_parse.rank)
    assert_equal('Foobar', name_parse.search_name)
    assert(name_parse.has_synonym())
    assert_equal(:Genus, name_parse.synonym_rank)
    assert_equal('Bazwoof', name_parse.synonym_search_name)
    assert_equal([], name_parse.find_names())
    assert_equal([], name_parse.find_synonym_names())
  end
end
