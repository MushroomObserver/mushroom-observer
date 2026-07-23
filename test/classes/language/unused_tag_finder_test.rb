# frozen_string_literal: true

require("test_helper")

class Language::UnusedTagFinderTest < UnitTestCase
  # Permanent regression guard for issue #4867: fails CI if a tag
  # loses its last reference (deleted caller, cascading orphan from
  # some other tag's removal, etc.) and nobody cleans it up. If this
  # fails on a tag that's actually reached via a new dynamic
  # `:"prefix_#{var}_suffix"` construction, add that pattern to
  # Language::UnusedTagFinder::KNOWN_DYNAMIC_* instead of ignoring
  # the failure.
  def test_no_unused_tags_remain
    result = Language::UnusedTagFinder.call

    assert_empty(
      result.confirmed_unused,
      "Found #{result.confirmed_unused.size} en.txt tag(s) with no " \
      "remaining reference anywhere: " \
      "#{result.confirmed_unused.join(", ")}. Delete them from en.txt " \
      "(then run `bin/rails lang:update`), or if this is a false " \
      "positive from a new dynamic tag-construction pattern, add it " \
      "to Language::UnusedTagFinder::KNOWN_DYNAMIC_*."
    )
  end

  def test_call_returns_a_sane_result_against_the_real_en_txt
    result = Language::UnusedTagFinder.call

    # Loose bounds on purpose -- this just confirms the tool found a
    # non-trivial catalog and scanned a real chunk of the repo, not
    # that today's exact tag/file counts hold. #4867's later purge
    # rounds will keep shrinking en.txt's total.
    assert_operator(result.total, :>, 1000,
                    "should have found a non-trivial en.txt catalog")
    assert_operator(result.files_scanned, :>, 500,
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
