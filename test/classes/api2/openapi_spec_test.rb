# frozen_string_literal: true

require("test_helper")

class API2
  class OpenapiSpecTest < UnitTestCase
    def test_top_level_shape
      spec = API2::OpenapiSpec.generate

      assert_equal("3.1.0", spec["openapi"])
      assert_equal("Mushroom Observer API", spec.dig("info", "title"))
      assert_equal(["/api2/observations", "/api2/names"],
                   spec["paths"].keys)
    end

    def test_get_query_params_introspected_from_help
      get = API2::OpenapiSpec.generate.dig("paths", "/api2/observations",
                                           "get")

      names = get["parameters"].pluck("name")
      assert_includes(names, "date")
      assert_includes(names, "north")
      # Description comes from the param's help: annotation.
      date = get["parameters"].find { |p| p["name"] == "date" }
      assert(date["description"].present?)
    end

    def test_latitude_type_mapping
      get = API2::OpenapiSpec.generate.dig("paths", "/api2/observations",
                                           "get")
      north = get["parameters"].find { |p| p["name"] == "north" }

      assert_equal("number", north.dig("schema", "type"))
      assert_equal(-90, north.dig("schema", "minimum"))
    end

    def test_post_has_request_body_with_create_params
      post = API2::OpenapiSpec.generate.dig("paths", "/api2/observations",
                                            "post")
      props = post.dig("requestBody", "content", "application/json",
                       "schema", "properties")

      assert(props.key?("name"), "create body should include name")
      assert_equal([{ "api_key" => [] }], post["security"])
    end

    def test_patch_separates_query_from_update_body
      patch = API2::OpenapiSpec.generate.dig("paths", "/api2/observations",
                                             "patch")

      assert(patch["parameters"].any?, "patch selects which to update")
      assert(patch.dig("requestBody", "content", "application/json",
                       "schema", "properties").any?)
    end

    def test_to_yaml_is_alias_free_and_parses
      yaml = API2::OpenapiSpec.to_yaml

      assert_no_match(/ &\d| \*\d/, yaml, "YAML should have no anchors")
      parsed = YAML.safe_load(yaml)
      assert_equal("3.1.0", parsed["openapi"])
    end

    def test_generator_leaves_no_temp_api_keys
      before = APIKey.where(notes: "openapi-spec-generator").count
      API2::OpenapiSpec.generate
      after = APIKey.where(notes: "openapi-spec-generator").count

      assert_equal(before, after, "temp keys must be cleaned up")
    end
  end
end
