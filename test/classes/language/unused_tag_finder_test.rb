# frozen_string_literal: true

require("test_helper")

class Language::UnusedTagFinderTest < UnitTestCase
  def test_call_returns_a_sane_result_against_the_real_en_txt
    result = Language::UnusedTagFinder.call

    assert_operator(result.total, :>, 3000,
                    "should have found roughly the whole en.txt catalog")
    assert_operator(result.files_scanned, :>, 1000,
                    "should have scanned a substantial part of the repo")
    # A core, unmistakably-live tag should never show up as unused.
    assert_not_includes(result.confirmed_unused, "add_object")
    assert_not_includes(result.protected_tags, "add_object")
  end

  # Regression guard for the exact gap that caused #4871's email_address
  # bug: a Symbol passed as a keyword *argument* to another embedded
  # tag (`field=:some_tag`) is a real reference, not just a direct
  # `[:some_tag]` embedding.
  def test_scan_en_txt_self_references_finds_argument_value_symbols
    finder = Language::UnusedTagFinder.new
    finder.instance_variable_set(
      :@en_txt,
      "  validate_user_email_too_long: " \
      '"[:validate_too_long(field=:email_address,max=80)]"' \
      "\n"
    )
    found = Set.new

    finder.send(:scan_en_txt_self_references, found)

    assert_includes(found, "validate_too_long",
                    "direct [:tag] embedding should be found")
    assert_includes(found, "email_address",
                    "Symbol keyword-argument value should be found")
  end

  def test_known_dynamic_tag_matches_curated_patterns
    finder = Language::UnusedTagFinder.new

    assert(finder.send(:known_dynamic_tag?, "log_observation_created"),
           "prefix match")
    assert(finder.send(:known_dynamic_tag?, "runtime_bulk_help"),
           "suffix match")
    assert(finder.send(:known_dynamic_tag?, "location_term_north"),
           "substring match")
    assert(finder.send(:known_dynamic_tag?, "show_name_creator"),
           "prefix+suffix pair match")
    assert(finder.send(:known_dynamic_tag?, "prev_object"),
           "exact match")
    assert_not(finder.send(:known_dynamic_tag?, "totally_unrelated_tag"))
  end

  def test_naive_plural_of_real_tag
    finder = Language::UnusedTagFinder.new
    tag_set = Set.new(%w[collection_number])

    assert(finder.send(:naive_plural_of_real_tag?, "collection_numbers",
                       tag_set))
    assert_not(finder.send(:naive_plural_of_real_tag?, "collection_number",
                           tag_set))
    assert_not(finder.send(:naive_plural_of_real_tag?, "unrelated_tags",
                           tag_set))
  end
end
