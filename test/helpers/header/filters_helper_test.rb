# frozen_string_literal: true

require("test_helper")

# Tests for Header::FiltersHelper#type_tags_to_label — the filter
# caption type-tag formatter. Covers the SENTINEL_TYPE_TAGS branches
# (`"all"` and `"none"`) and the normal pluralize-and-localize path.
#
# Originally surfaced via
# `RssLogsControllerTest#test_type_filter_rejects_invalid_types`
# (the `:NONES` bug), but that test only asserts the controller
# behavior, not the caption output. This file covers the helper
# directly so future refactors of `SENTINEL_TYPE_TAGS` or the
# `pluralize.upcase.to_sym` path can't silently regress.
module Header
  class FiltersHelperTest < ActionView::TestCase
    include FiltersHelper

    def test_all_sentinel_maps_to_all_label
      assert_equal(:ALL.l, type_tags_to_label("all"))
    end

    def test_none_sentinel_maps_to_none_label
      # This is the regression case: the controller sanitizes invalid
      # type tags down to `"none"`, then the caption gets rendered.
      # Pre-SENTINEL_TYPE_TAGS this hit `:NONES.l` (no such translation)
      # and triggered the missing-translations check in test teardown.
      assert_equal(:NONE.l, type_tags_to_label("none"))
    end

    def test_normal_tag_pluralizes_and_localizes
      # `"observation"` → `"observations".upcase.to_sym` → `:OBSERVATIONS`
      assert_equal(:OBSERVATIONS.l, type_tags_to_label("observation"))
    end

    def test_pluralize_runs_before_upcase
      # Order matters: `tag.pluralize.upcase` (correct) vs
      # `tag.upcase.pluralize` (broken — Inflector adds lowercase 's',
      # yielding `:SPECIES_LISTs`).
      assert_equal(:SPECIES_LISTS.l, type_tags_to_label("species_list"))
    end

    def test_multiple_tags_joined_by_comma
      result = type_tags_to_label("observation species_list")

      assert_equal("#{:OBSERVATIONS.l}, #{:SPECIES_LISTS.l}", result)
    end

    def test_mix_of_sentinel_and_normal_tags
      result = type_tags_to_label("all observation")

      assert_equal("#{:ALL.l}, #{:OBSERVATIONS.l}", result)
    end

    def test_confidence_val_as_label_with_array_joins_with_dash
      vals = [0.6, 1.0]
      expected = vals.map { |v| Vote.confidence(v.to_f) }.join(" – ")

      assert_equal(expected, confidence_val_as_label(vals),
                   "Expected array of confidence values joined by em-dash")
    end

    def test_confidence_val_as_label_with_scalar
      assert_equal(Vote.confidence(0.6), confidence_val_as_label(0.6),
                   "Expected single confidence label for scalar input")
    end

    def test_filter_truncate_joined_string_truncates_long_string
      long_str = "Amanita muscaria, " * 6 # > 100 chars
      result = filter_truncate_joined_string(long_str, [])

      assert_equal("#{long_str[0...97]}...", result,
                   "Expected string longer than 100 chars to be truncated")
    end
  end
end
