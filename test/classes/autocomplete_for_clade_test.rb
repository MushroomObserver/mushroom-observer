# frozen_string_literal: true

require "test_helper"

class AutocompleteForCladeTest < UnitTestCase
  def test_rough_matches_defaults_to_above_genus
    auto = Autocomplete::ForClade.new(string: "Agaric")

    names = auto.rough_matches("A").pluck(:name)

    assert_includes(names, names(:agaricaceae).text_name)
    assert_includes(names, names(:agaricales).text_name)
  end

  def test_rough_matches_excludes_group_regardless_of_min_rank
    auto = Autocomplete::ForClade.new(string: "Boletus", min_rank: "Species")

    names = auto.rough_matches("B").pluck(:name)

    assert_not_includes(names, names(:boletus_edulis_group).text_name)
  end

  def test_rough_matches_honors_min_rank
    auto = Autocomplete::ForClade.new(string: "Agaric", min_rank: "Family")

    names = auto.rough_matches("A").pluck(:name)

    assert_includes(names, names(:agaricales).text_name)
    assert_not_includes(names, names(:agaricaceae).text_name)
  end

  def test_invalid_min_rank_falls_back_to_genus
    auto = Autocomplete::ForClade.new(string: "Boletus", min_rank: "bogus")

    assert_equal(:Genus, auto.min_rank)
  end

  def test_blank_min_rank_falls_back_to_genus
    auto = Autocomplete::ForClade.new(string: "Boletus")

    assert_equal(:Genus, auto.min_rank)
  end

  def test_symbol_min_rank_is_valid_and_normalized
    auto = Autocomplete::ForClade.new(string: "Boletus", min_rank: :Family)

    assert_equal(:Family, auto.min_rank)
  end

  def test_string_min_rank_is_normalized_to_symbol
    auto = Autocomplete::ForClade.new(string: "Boletus", min_rank: "Family")

    assert_equal(:Family, auto.min_rank)
  end
end
