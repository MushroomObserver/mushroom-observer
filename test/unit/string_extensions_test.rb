# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class StringExtensionsTest < UnitTestCase

  def test_binary_length
    str = 'abčde';
    assert_equal(5, str.length)
    assert_equal(6, str.binary_length)
    assert_equal('abčd', str.truncate_binary_length(5))
    assert_equal('abč', str.truncate_binary_length(4))
    assert_equal('ab', str.truncate_binary_length(3))
    assert_equal('ab', str.truncate_binary_length(2))
    assert_equal('a', str.truncate_binary_length(1))
    assert_equal('', str.truncate_binary_length(0))
  end

  def test_levenshtein_distance
    assert_equal(3, ''.levenshtein_distance_to('abc'))          # 3 add
    assert_equal(6, ''.levenshtein_distance_to('abc', 2, 1, 1))
    assert_equal(3, ''.levenshtein_distance_to('abc', 1, 2, 1))
    assert_equal(3, ''.levenshtein_distance_to('abc', 1, 1, 2))

    assert_equal(3, 'abc'.levenshtein_distance_to(''))          # 3 del
    assert_equal(3, 'abc'.levenshtein_distance_to('', 2, 1, 1))
    assert_equal(6, 'abc'.levenshtein_distance_to('', 1, 2, 1))
    assert_equal(3, 'abc'.levenshtein_distance_to('', 1, 1, 2))

    assert_equal(3, 'abc'.levenshtein_distance_to('def'))           # 3 chg
    assert_equal(3, 'abc'.levenshtein_distance_to('def', 2, 1, 1))
    assert_equal(3, 'abc'.levenshtein_distance_to('def', 1, 2, 1))
    assert_equal(6, 'abc'.levenshtein_distance_to('def', 1, 1, 2))  # 3 chg = 3 add + 3 del
    assert_equal(6, 'abc'.levenshtein_distance_to('def', 1, 1, 10)) # 3 add + 3 del

    assert_equal(3, 'çŚ©'.levenshtein_distance_to('Äøµ'))
    assert_equal(1, 'Agaricus campestris'.levenshtein_distance_to('Agaricus campestras'))
    assert_equal(2, 'Physcia'.levenshtein_distance_to('Phycsia'))

    assert_equal(1.0000, 'Physcia'.percent_match('Physcia').round(4))
    assert_equal(0.0000, 'freedom'.percent_match('Physcia').round(4))
    assert_equal(0.7143, 'Physcia'.percent_match('Phycsia').round(4))
    assert_equal(0.8421, 'Agaricis Campestras'.percent_match('Agaricus campestris').round(4))
  end
end
