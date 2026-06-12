# frozen_string_literal: true

require("test_helper")

class Inat
  class PageParserTest < UnitTestCase
    def test_raises_if_not_own_import_has_no_username_or_ids
      import = inat_imports(:dick_inat_import).tap do |i|
        i.import_others = true
        i.inat_username = ""
        i.inat_ids = ""
      end

      assert_raises(ArgumentError) { PageParser.new(import) }
    end

    def test_does_not_raise_if_not_own_import_has_username
      import = inat_imports(:dick_inat_import).tap do |i|
        i.import_others = true
        i.inat_username = "some_user"
        i.inat_ids = ""
      end

      assert_nothing_raised { PageParser.new(import) }
    end

    def test_does_not_raise_if_not_own_import_has_ids
      import = inat_imports(:dick_inat_import).tap do |i|
        i.import_others = true
        i.inat_username = ""
        i.inat_ids = "123,456"
      end

      assert_nothing_raised { PageParser.new(import) }
    end

    def test_does_not_raise_if_not_own_import_has_url
      import = inat_imports(:dick_inat_import).tap do |i|
        i.import_others = true
        i.inat_username = ""
        i.inat_ids = ""
        i.inat_url = "project_id=291058"
      end

      assert_nothing_raised { PageParser.new(import) }
    end

    def test_url_request_query_args_merges_url_params
      import = inat_imports(:dick_inat_import).tap do |i|
        i.inat_url = "project_id=291058&place_id=5"
      end
      parser = PageParser.new(import)

      args = parser.send(:url_request_query_args, id_above: 0)

      assert_equal("291058", args[:project_id],
                   "URL param project_id should be in query args")
      assert_equal("5", args[:place_id],
                   "URL param place_id should be in query args")
    end

    def test_url_request_query_args_safety_params_override_url
      import = inat_imports(:dick_inat_import).tap do |i|
        # URL tries to override taxon_id and without_field — both should
        # be replaced by MO's required values.
        i.inat_url = "project_id=291058&taxon_id=1&without_field=something"
      end
      parser = PageParser.new(import)

      args = parser.send(:url_request_query_args, id_above: 0)

      assert_equal(
        Inat::Constants::IMPORTABLE_TAXON_IDS_ARG,
        args[:taxon_id],
        "MO taxon_id should override any taxon_id in user URL"
      )
      assert_equal(
        "Mushroom Observer URL",
        args[:without_field],
        "MO without_field should override any without_field in user URL"
      )
    end

    def test_url_request_query_args_strips_id_key
      import = inat_imports(:dick_inat_import).tap do |i|
        i.inat_url = "project_id=291058&id=123,456"
      end
      parser = PageParser.new(import)

      args = parser.send(:url_request_query_args, id_above: 0)

      assert_nil(args[:id],
                 "URL mode should not pass id filter (uses id_above instead)")
    end

    def test_url_request_query_args_strips_only_id_key
      import = inat_imports(:dick_inat_import).tap do |i|
        i.inat_url = "project_id=291058&only_id=true"
      end
      parser = PageParser.new(import)

      args = parser.send(:url_request_query_args, id_above: 0)

      assert_nil(args[:only_id],
                 "URL mode must not pass only_id — importer needs full JSON")
    end

    def test_url_request_query_args_strips_mo_controlled_keys_from_stored_query
      # Simulate a stored query string that somehow contains MO-controlled keys
      # (e.g. from a confirm round-trip of an older normalized value).
      import = inat_imports(:dick_inat_import).tap do |i|
        i.inat_url = "project_id=291058&taxon_id=9999&page=2&per_page=50" \
                     "&order=desc&order_by=created_at&without_field=foo" \
                     "&only_id=true&ttl=300&id=123"
      end
      parser = PageParser.new(import)

      args = parser.send(:url_request_query_args, id_above: 0)

      assert_equal("291058", args[:project_id],
                   "project_id should be preserved")
      [:taxon_id, :page, :per_page, :order, :order_by, :without_field,
       :only_id, :ttl, :id].each do |key|
        assert_nil(args[key],
                   "#{key} should be stripped from stored query string")
      end
    end

    def test_url_request_query_args_sets_pagination_params
      import = inat_imports(:dick_inat_import).tap do |i|
        i.inat_url = "project_id=291058"
      end
      parser = PageParser.new(import)

      args = parser.send(:url_request_query_args, id_above: 42)

      assert_equal(42, args[:id_above], "id_above should be set from argument")
      assert_equal(200, args[:per_page], "per_page should be 200")
      assert_equal("asc", args[:order], "order should be asc for pagination")
      assert_equal("id", args[:order_by],
                   "order_by should be id for pagination")
    end

    def test_next_page_url_mode_returns_parsed_json
      import = inat_imports(:dick_inat_import).tap do |i|
        i.inat_url = "project_id=291058"
      end
      parser = PageParser.new(import)
      body = { "results" => [], "total_results" => 0 }.to_json

      stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
        to_return(status: 200, body: body)

      result = parser.next_page

      assert_equal({ "results" => [], "total_results" => 0 }, result,
                   "next_page should return parsed JSON in URL mode")
    end

    def test_next_url_request_rescues_rest_client_exception
      import = inat_imports(:dick_inat_import).tap do |i|
        i.inat_url = "project_id=291058"
      end
      parser = PageParser.new(import)

      stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
        to_return(status: 401, body: '{"error":"Unauthorized"}')

      result = parser.next_page

      assert_nil(result,
                 "next_page should return nil when API returns an error")
      assert_not_empty(import.response_errors,
                       "API error should be logged to import.response_errors")
    end

    def test_url_id_above_used_for_first_page
      import = inat_imports(:dick_inat_import).tap do |i|
        i.inat_url = "project_id=291058&id_above=500"
      end
      parser = PageParser.new(import)

      args = parser.send(:url_request_query_args, id_above: 0)

      assert_equal(500, args[:id_above],
                   "URL id_above should be used for the first page " \
                   "(internal cursor still at 0)")
    end

    def test_internal_id_above_overrides_url_on_subsequent_pages
      import = inat_imports(:dick_inat_import).tap do |i|
        i.inat_url = "project_id=291058&id_above=500"
      end
      parser = PageParser.new(import)

      args = parser.send(:url_request_query_args, id_above: 750)

      assert_equal(750, args[:id_above],
                   "Internal cursor should override URL id_above after " \
                   "the first page")
    end
  end
end
