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
            "&taxon_id=47170&iconic_taxa=Fungi&id=123,456" \
            "&without_field=Mushroom+Observer+URL&only_id=true"
      result = URLNormalizer.new(url).normalize

      assert_equal("project_id=291058", result,
                   "Should strip taxon_id, iconic_taxa, id, without_field, " \
                   "only_id")
    end

    def test_preserves_project_place_quality_and_license_params
      url = "#{SITE_URL}?project_id=291058&place_id=5&quality_grade=research" \
            "&license=cc-by&user_login=testuser"
      result = URLNormalizer.new(url).normalize

      assert_equal(
        "license=cc-by&place_id=5&project_id=291058" \
        "&quality_grade=research&user_login=testuser",
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

    # ---- whitespace handling ------------------------------------------------

    def test_leading_trailing_whitespace_is_stripped
      url = "  #{SITE_URL}?project_id=291058  "
      result = URLNormalizer.new(url).normalize

      assert_equal("project_id=291058", result,
                   "Should strip leading/trailing whitespace from input")
    end
  end
end
