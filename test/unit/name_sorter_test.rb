require File.dirname(__FILE__) + '/../test_helper'

class NameSorterTest < Test::Unit::TestCase
  fixtures :names
  
  def test_add_name_default
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name('Foo bar')
    assert_equal(['Foo bar'], name_sorter.new_name_strs)
    assert_equal(['Foo bar'], name_sorter.new_line_strs)
    assert_equal([], name_sorter.all_names)
  end

  def test_add_name_coprinus_comatus
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name(@coprinus_comatus.text_name)
    assert_equal([], name_sorter.new_name_strs)
    assert_equal([], name_sorter.new_line_strs)
    assert_equal([@coprinus_comatus], name_sorter.all_names)
  end
  
  def test_add_name_explicit
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name('Species Foo bar')
    assert_equal(['Foo bar'], name_sorter.new_name_strs)
    assert_equal(['Species Foo bar'], name_sorter.new_line_strs)
    assert_equal([], name_sorter.all_names)
  end
  
  def test_add_name_genus
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name('Genus Foobar')
    assert_equal(['Foobar'], name_sorter.new_name_strs)
    assert_equal(['Genus Foobar'], name_sorter.new_line_strs)
    assert_equal([], name_sorter.all_names)
  end
  
  def test_add_name_genus_psalliota
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name("#{@psalliota.rank} #{@psalliota.text_name}")
    assert_equal([], name_sorter.new_name_strs)
    assert_equal([], name_sorter.new_line_strs)
    assert_equal([@psalliota], name_sorter.all_names)
  end

  def test_add_name_default_synonym_lepiota
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name("#{@macrolepiota_rachodes.text_name} = #{@lepiota_rachodes.text_name}")
    assert_equal([], name_sorter.new_name_strs)
    assert_equal([], name_sorter.new_line_strs)
    assert_equal([@macrolepiota_rachodes], name_sorter.all_names)
    assert_equal([@lepiota_rachodes], name_sorter.synonym_data[0][0].find_synonym_names())
  end

  def test_add_name_default_synonym
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name('Foo bar = Baz woof')
    assert_equal(['Foo bar', 'Baz woof'], name_sorter.new_name_strs)
    assert_equal(['Foo bar = Baz woof'], name_sorter.new_line_strs)
    assert_equal([], name_sorter.all_names)
  end

  def test_add_name_genus_synonym_agaricus
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name("#{@agaricus.rank} #{@agaricus.text_name} = #{@psalliota.rank} #{@psalliota.text_name}")
    assert_equal([], name_sorter.new_name_strs)
    assert_equal([], name_sorter.new_line_strs)
    assert_equal([@agaricus], name_sorter.all_names)
    assert_equal([@psalliota], name_sorter.synonym_data[0][0].find_synonym_names())
  end

  def test_add_name_genus_synonym
    name_sorter = NameSorter.new
    assert_not_nil(name_sorter)
    name_sorter.add_name('Genus Foobar = Genus Bazwoof')
    assert_equal(['Foobar', 'Bazwoof'], name_sorter.new_name_strs)
    assert_equal(['Genus Foobar = Genus Bazwoof'], name_sorter.new_line_strs)
    assert_equal([], name_sorter.all_names)
  end
end
