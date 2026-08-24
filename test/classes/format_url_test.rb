# frozen_string_literal: true

require("test_helper")

# FormatURL validates URL *format* only. It runs inside ExternalSite and
# ExternalLink validation on every save, so it must not make a live
# network request -- a reachability check here previously fired a HEAD
# per save and 403'd on iNaturalist, making the iNaturalist site row
# unsaveable.
class FormatURLTest < UnitTestCase
  def test_well_formed_urls_are_valid
    assert(FormatURL.new("https://example.org/x").valid?)
    assert(FormatURL.new("http://example.org").valid?)
    # a bare host gets the https scheme prepended, then validates
    assert(FormatURL.new("example.org/x").valid?)
  end

  def test_malformed_urls_are_invalid
    assert_not(FormatURL.new("not a url").valid?, "whitespace is rejected")
    assert_not(FormatURL.new("").valid?, "empty yields no host")
  end

  def test_matches_the_shape_of_a_provided_base_url
    base = "https://www.mycoportal.org/portal/collections/"
    assert(FormatURL.new("#{base}list.php?catnum=1", base).valid?)
    assert_not(FormatURL.new("https://elsewhere.org/x", base).valid?,
               "a different host does not match the base_url")
  end

  # iNaturalist's CDN 403s an automated HEAD; validity must not depend on
  # reachability, and the network method must be gone entirely.
  def test_reachability_is_not_checked
    assert(FormatURL.new("https://www.inaturalist.org/observations/").valid?,
           "a well-formed URL is valid even where a HEAD would 403")
    assert_not(FormatURL.private_method_defined?(:url_exists?),
               "the live reachability check must be gone")
  end
end
