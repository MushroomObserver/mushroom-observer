# encoding: utf-8
require "test_helper"

# test extensions to Ruby and Rails String Class
class StringExtensionsTest < UnitTestCase
  def test_bytesize
    str = "abčde"
    assert_equal(5, str.length)
    assert_equal(6, str.bytesize)
    assert_equal("abčd", str.truncate_bytesize(5))
    assert_equal("abč", str.truncate_bytesize(4))
    assert_equal("ab", str.truncate_bytesize(3))
    assert_equal("ab", str.truncate_bytesize(2))
    assert_equal("a", str.truncate_bytesize(1))
    assert_equal("", str.truncate_bytesize(0))
  end

  def test_capitalize_first
    assert_equal("", "".capitalize_first)
    assert_equal("A", "a".capitalize_first)
    assert_equal("AB", "aB".capitalize_first)
    assert_equal("Abc", "abc".capitalize_first)
  end

  def test_dealphabetize
    # convert_base62_to_decimal
    assert_equal(0, "0".dealphabetize)
    assert_equal(42, "g".dealphabetize)
    assert_equal(123_456_789, "8M0kX".dealphabetize)

    # decimal_to_hex
    assert_equal(0, "0".dealphabetize("0123456789ABCDEF"))
    assert_equal(42, "2A".dealphabetize("0123456789ABCDEF"))
    assert_equal(123_456_789, "75BCD15".dealphabetize("0123456789ABCDEF"))

    assert_raises(RuntimeError) { "Z".dealphabetize("ABC") }
  end

  def test_random_no_seed_string
    srand 314_159
    random_str = String.random(10)
    assert_equal("l83parchj1", random_str)
  end

  def test_random_with_seed_string
    srand 314_159
    random_str = String.random(6, "mushroomobserver")
    assert_equal("ersovr", random_str)
  end

  def test_rand_char
    srand 314_159
    random_char = "Superman".rand_char
    assert_equal("e", random_char)
  end

  def test_truncate_bytesize
    assert_equal("aéioü", "aéioü".truncate_bytesize(7))
    assert_equal("aéio", "aéioü".truncate_bytesize(6))
    assert_equal("aéio", "aéioü".truncate_bytesize(5))
  end

  def test_levenshtein_distance
    assert_equal(3, "".levenshtein_distance_to("abc"))          # 3 add
    assert_equal(6, "".levenshtein_distance_to("abc", 2, 1, 1))
    assert_equal(3, "".levenshtein_distance_to("abc", 1, 2, 1))
    assert_equal(3, "".levenshtein_distance_to("abc", 1, 1, 2))

    assert_equal(3, "abc".levenshtein_distance_to(""))          # 3 del
    assert_equal(3, "abc".levenshtein_distance_to("", 2, 1, 1))
    assert_equal(6, "abc".levenshtein_distance_to("", 1, 2, 1))
    assert_equal(3, "abc".levenshtein_distance_to("", 1, 1, 2))

    assert_equal(3, "abc".levenshtein_distance_to("def"))       # 3 chg
    assert_equal(3, "abc".levenshtein_distance_to("def", 2, 1, 1))
    assert_equal(3, "abc".levenshtein_distance_to("def", 1, 2, 1))
    # 3 chg = 3 add + 3 del
    assert_equal(6, "abc".levenshtein_distance_to("def", 1, 1, 2))
    # 3 add + 3 del
    assert_equal(6, "abc".levenshtein_distance_to("def", 1, 1, 10))

    assert_equal(3, "çŚ©".levenshtein_distance_to("Äøµ"))
    assert_equal(1, "Agaricus campestris".
      levenshtein_distance_to("Agaricus campestras"))
    assert_equal(2, "Physcia".levenshtein_distance_to("Phycsia"))

    assert_equal(1.0000, "Physcia".percent_match("Physcia").round(4))
    assert_equal(0.0000, "freedom".percent_match("Physcia").round(4))
    assert_equal(0.7143, "Physcia".percent_match("Phycsia").round(4))
    assert_equal(0.8421, "Agaricis Campestras".
      percent_match("Agaricus campestris").round(4))
  end
end
