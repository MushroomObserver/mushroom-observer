# frozen_string_literal: true

require("test_helper")

# test extensions to Ruby and Rails String Class
class StringExtensionsTest < UnitTestCase
  def test_pluralized_title
    assert_equal("Good Dogs", "good dog".pluralized_title)
    assert_equal("Observations", "Observation".pluralized_title)
    assert_equal("Glossary Terms", "GlossaryTerm".pluralized_title)
    assert_equal("Species Lists", "SpeciesList".pluralized_title)
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
    srand(314_159)
    random_str = String.random(10)
    assert_equal("l83parchj1", random_str)
  end

  def test_random_with_seed_string
    srand(314_159)
    random_str = String.random(6, "mushroomobserver")
    assert_equal("ersovr", random_str)
  end

  def test_rand_char
    srand(314_159)
    random_char = "Superman".rand_char
    assert_equal("e", random_char)
  end

  def test_string_truncate_html
    assert_equal("123", "123".truncate_html(5))
    assert_equal("12345", "12345".truncate_html(5))
    assert_equal("1234...", "123456".truncate_html(5))
    assert_equal("<i>1234...</i>", "<i>123456</i>".truncate_html(5))
    assert_equal("<i>12<b>3</b>4...</i>",
                 "<i>12<b>3</b>456</i>".truncate_html(5))
    assert_equal("<i>12<b>3<hr/></b>4...</i>",
                 "<i>12<b>3<hr/></b>456</i>".truncate_html(5))
    assert_equal("<i>12</i>3<b>4...</b>",
                 "<i>12</i>3<b>456</b>".truncate_html(5))
    assert_equal("malformatted", "malformatted<; HTML".truncate_html(20))
  end

  def test_iconv
    assert_equal("áëìøũ", "áëìøũ".iconv("utf-8").encode("utf-8"))
    assert_equal("áëìøu", "áëìøũ".iconv("iso8859-1").encode("utf-8"))
    assert_equal("aeiou", "áëìøũ".iconv("ascii-8bit").encode("utf-8"))
    assert_equal("ενα", "ενα".iconv("utf-8").encode("utf-8"))
    assert_equal("???", "ενα".iconv("ascii-8bit").encode("utf-8"))
  end

  def test_character_asciiness
    assert("a".is_ascii_character?)
    assert_not("á".is_ascii_character?)
  end

  ### Test extensions used with Textile ###
  def test_tp_nodiv
    assert("<p>a</p>", "a".tp_nodiv)
  end
end
