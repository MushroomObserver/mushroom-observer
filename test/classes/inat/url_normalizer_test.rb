# frozen_string_literal: true

require("test_helper")

class Inat
  class URLNormalizerTest < UnitTestCase
    SITE_URL = "https://www.inaturalist.org/observations"
    API_URL  = "https://api.inaturalist.org/v1/observations"

    # ---- valid iNat observation URLs ----------------------------------------

    def test_observation_search_url_returns_query_string
      url = "#{SITE_URL}?project_id=291058&place_id=1"
      result = URLNormalizer.new(url).normalize

      assert_equal("place_id=1&project_id=291058", result,
                   "Should return sorted query string from site URL")
    end

    def test_api_url_returns_query_string
      url = "#{API_URL}?project_id=291058&quality_grade=research"
      result = URLNormalizer.new(url).normalize

      assert_equal("project_id=291058&quality_grade=research", result,
                   "Should return query string from API URL")
    end

    def test_strips_ui_only_params
      url = "#{SITE_URL}?project_id=291058&subview=table&view=table"
      result = URLNormalizer.new(url).normalize

      assert_equal("project_id=291058", result,
                   "Should strip subview and view params")
    end

    def test_strips_mo_controlled_pagination_params
      url = "#{API_URL}?project_id=291058" \
            "&page=2&per_page=50&order=desc&order_by=created_at"
      result = URLNormalizer.new(url).normalize

      assert_equal(
        "project_id=291058", result,
        "Should strip user-supplied page, per_page, order, order_by params"
      )
    end

    def test_preserves_id_above_param
      url = "#{API_URL}?project_id=291058&id_above=500"
      result = URLNormalizer.new(url).normalize

      assert_equal("id_above=500&project_id=291058", result,
                   "id_above should be kept so PageParser can use it as " \
                   "the starting cursor for the first page")
    end

    def test_strips_mo_controlled_filter_params
      url = "#{API_URL}?project_id=291058" \
            "&taxon_id=47170&without_field=Mushroom+Observer+URL" \
            "&only_id=true&ttl=300&apply_project_rules_for=123"
      result = URLNormalizer.new(url).normalize

      assert_equal(
        "project_id=291058", result,
        "Should strip taxon_id, without_field, only_id, ttl, " \
        "apply_project_rules_for"
      )
    end

    def test_preserves_project_place_quality_and_license_params
      url = "#{SITE_URL}?project_id=291058&place_id=5&quality_grade=research" \
            "&license=cc-by"
      result = URLNormalizer.new(url).normalize

      assert_equal(
        "license=cc-by&place_id=5&project_id=291058&quality_grade=research",
        result,
        "Should preserve filter params meaningful to the user"
      )
    end

    def test_preserves_licensed_false_param
      url = "#{SITE_URL}?project_id=291058&licensed=false"
      result = URLNormalizer.new(url).normalize

      assert_equal("licensed=false&project_id=291058", result,
                   "Should preserve licensed param")
    end

    def test_strips_all_controlled_params_leaving_empty_string
      url = "#{API_URL}?subview=table&taxon_id=47170&order_by=created_at"
      result = URLNormalizer.new(url).normalize

      assert_equal("", result,
                   "Should return empty string when all params are stripped")
    end

    def test_url_with_no_query_string_returns_empty_string
      url = SITE_URL
      result = URLNormalizer.new(url).normalize

      assert_equal("", result,
                   "URL with no query string should return empty string")
    end

    # ---- invalid / non-iNat URLs -------------------------------------------

    def test_non_inat_url_returns_nil
      result = URLNormalizer.new("https://example.com/observations?q=1").normalize

      assert_nil(result, "Non-iNat URL should return nil")
    end

    def test_inat_non_observations_path_returns_nil
      result = URLNormalizer.new(
        "https://www.inaturalist.org/taxa/47170"
      ).normalize

      assert_nil(result,
                 "iNat URL for a non-observations path should return nil")
    end

    def test_unparseable_url_returns_nil
      result = URLNormalizer.new("not a url at all").normalize

      assert_nil(result, "Unparseable input should return nil")
    end

    def test_blank_string_returns_nil
      assert_nil(URLNormalizer.new("").normalize,
                 "Blank string should return nil")
    end

    def test_api_non_observations_path_returns_nil
      result = URLNormalizer.new(
        "https://api.inaturalist.org/v1/taxa?q=fungi"
      ).normalize

      assert_nil(result,
                 "iNat API URL for a non-observations path should return nil")
    end

    # ---- context-dependent stripping ----------------------------------------

    def test_strips_user_login_by_default
      url = "#{API_URL}?project_id=291058&user_login=testuser"
      result = URLNormalizer.new(url).normalize

      assert_equal("project_id=291058", result,
                   "Should strip user_login for non-superimporters")
    end

    def test_strips_user_id_by_default
      url = "#{API_URL}?project_id=291058&user_id=12345"
      result = URLNormalizer.new(url).normalize

      assert_equal("project_id=291058", result,
                   "Should strip user_id for non-superimporter")
    end

    def test_superimporter_own_import_strips_user_id
      url = "#{API_URL}?project_id=291058&user_login=testuser&user_id=12345"
      result = URLNormalizer.new(url, superimporter: true).normalize

      assert_equal("project_id=291058&user_login=testuser", result,
                   "user_id stripped for own-import superimporter; " \
                   "user_login preserved")
    end

    def test_superimporter_import_others_preserves_user_id
      url = "#{API_URL}?project_id=291058&user_id=12345"
      result = URLNormalizer.new(url, superimporter: true,
                                      import_others: true).normalize

      assert_equal(
        "project_id=291058&user_id=12345", result,
        "user_id should be kept for superimporter in import-others " \
        "mode so the import can be scoped to a specific user"
      )
    end

    def test_superimporter_import_others_strips_user_id_when_user_login_present
      url = "#{API_URL}?project_id=291058&user_id=12345&user_login=testuser"
      result = URLNormalizer.new(url, superimporter: true,
                                      import_others: true).normalize

      assert_equal("project_id=291058&user_login=testuser", result,
                   "user_id stripped when user_login also present to prevent " \
                   "iNat from ORing them and returning cross-user results")
    end

    def test_non_superimporter_strips_user_login_and_user_id
      url = "#{API_URL}?project_id=291058&user_login=testuser&user_id=12345"
      result = URLNormalizer.new(url).normalize

      assert_equal("project_id=291058", result,
                   "Should strip Both user_login and user_id stripped for " \
                   "non-superimporters")
    end

    def test_superimporter_strips_licensed
      url = "#{API_URL}?project_id=291058&licensed=false"
      result = URLNormalizer.new(url, superimporter: true).normalize

      assert_equal("project_id=291058", result,
                   "licensed should be stripped for superimporters")
    end

    def test_import_others_strips_licensed
      url = "#{API_URL}?project_id=291058&licensed=false"
      result = URLNormalizer.new(url, import_others: true).normalize

      assert_equal(
        "project_id=291058", result,
        "`licensed` param should be stripped if importing others' observation"
      )
    end

    def test_own_non_superimporter_preserves_licensed
      url = "#{API_URL}?project_id=291058&licensed=false"
      result = URLNormalizer.new(url,
                                 superimporter: false,
                                 import_others: false).normalize

      assert_equal("licensed=false&project_id=291058", result,
                   "Should preserve regular user's iNat `licensed` param ")
    end

    # ---- #ignored_params ----------------------------------------------------

    def test_ignored_params_silent_for_ui_noise_in_site_url
      url = "#{SITE_URL}?project_id=291058&page=2&order=desc" \
            "&order_by=created_at&per_page=50&subview=table&view=table"
      ignored = URLNormalizer.new(url).ignored_params

      assert_empty(ignored,
                   "Pagination/display params from a www.inaturalist.org " \
                   "URL are expected UI noise and should not warn the user")
    end

    def test_ignored_params_warns_for_ui_noise_in_api_url
      url = "#{API_URL}?project_id=291058&page=2&order=desc"
      ignored = URLNormalizer.new(url).ignored_params

      assert_includes(ignored, "page",
                      "page in an API URL is unexpected and should warn")
      assert_includes(ignored, "order",
                      "order in an API URL is unexpected and should warn")
    end

    def test_ignored_params_returns_always_stripped_params
      url = "#{API_URL}?project_id=291058&taxon_id=47170&page=2"
      ignored = URLNormalizer.new(url).ignored_params

      assert_includes(ignored, "taxon_id",
                      "taxon_id is always stripped and should appear in " \
                      "ignored_params")
      assert_includes(ignored, "page",
                      "page is always stripped and should appear in " \
                      "ignored_params")
      assert_not_includes(ignored, "project_id",
                          "project_id is kept and should not appear in " \
                          "ignored_params")
    end

    def test_ignored_params_returns_context_stripped_params
      url = "#{API_URL}?project_id=291058&user_login=testuser"
      ignored = URLNormalizer.new(url).ignored_params

      assert_includes(ignored, "user_login",
                      "user_login stripped for non-superimporter should " \
                      "appear in ignored_params")
    end

    def test_ignored_params_returns_empty_for_clean_url
      url = "#{API_URL}?project_id=291058&place_id=5"
      ignored = URLNormalizer.new(url).ignored_params

      assert_empty(ignored,
                   "No params should be ignored when URL has only " \
                   "pass-through params")
    end

    def test_ignored_params_returns_nil_for_invalid_url
      ignored = URLNormalizer.new("https://example.com/observations").
                ignored_params

      assert_nil(ignored,
                 "ignored_params should return nil for a non-iNat URL")
    end

    # ---- whitespace handling ------------------------------------------------

    def test_leading_trailing_whitespace_is_stripped
      url = "  #{SITE_URL}?project_id=291058  "
      result = URLNormalizer.new(url).normalize

      assert_equal("project_id=291058", result,
                   "Should strip leading/trailing whitespace from input")
    end
  end
end
