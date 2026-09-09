# frozen_string_literal: true

require("test_helper")

class API2
  class OpenapiSpecTest < UnitTestCase
    # Generating the spec introspects every resource/method pair, so
    # build it once and share it across the assertions below.
    def self.spec
      @spec ||= API2::OpenapiSpec.generate
    end

    delegate :spec, to: :class

    def test_top_level_shape
      assert_equal("3.1.0", spec["openapi"])
      assert_equal("Mushroom Observer API", spec.dig("info", "title"))
      expected = API2::OpenapiSpec::RESOURCES.values.
                 map { |plural| "/api2/#{plural}" }
      assert_equal(expected, spec["paths"].keys)
      assert_equal(20, spec["paths"].size)
    end

    def test_detail_and_page_are_documented
      detail = spec.dig("components", "parameters", "detail")
      assert_equal(%w[none low high], detail.dig("schema", "enum"))
      assert(detail["description"].present?)

      %w[get post patch].each do |method|
        params = spec.dig("paths", "/api2/observations", method,
                          "parameters")
        assert_includes(params,
                        { "$ref" => "#/components/parameters/detail" },
                        "#{method} should reference the detail param")
        assert_includes(params,
                        { "$ref" => "#/components/parameters/page" })
      end
    end

    def test_results_envelope_covers_detail_none_and_low
      schema = spec.dig("paths", "/api2/observations", "get", "responses",
                        "200", "content", "application/json", "schema")

      assert(schema.dig("properties", "number_of_records").present?)
      items = schema.dig("properties", "results", "items")
      assert_equal([{ "type" => "integer" },
                    API2::OpenapiSpec::ResponseSchemas::SCHEMAS[:observation]],
                   items["oneOf"])
    end

    def test_security_scheme_is_defined
      scheme = spec.dig("components", "securitySchemes", "api_key")

      assert_equal({ "type" => "apiKey", "in" => "query",
                     "name" => "api_key" }, scheme)
    end

    def test_response_schemas_cover_every_resource
      assert_equal(API2::OpenapiSpec::RESOURCES.keys,
                   API2::OpenapiSpec::ResponseSchemas::SCHEMAS.keys)
    end

    # Resources whose API2 subclass raises NoMethodForAction for a
    # method must not list that method in the spec.
    def test_unsupported_methods_are_omitted
      assert_equal(["post"], spec.dig("paths", "/api2/api_keys").keys)
      assert_equal(["get"], spec.dig("paths", "/api2/external_sites").keys)
      assert_equal(["get"], spec.dig("paths", "/api2/herbaria").keys)
      assert_equal(["get"],
                   spec.dig("paths", "/api2/location_descriptions").keys)
      assert_equal(["get"], spec.dig("paths", "/api2/name_descriptions").keys)
      assert_equal(%w[get post patch],
                   spec.dig("paths", "/api2/locations").keys)
      assert_equal(%w[get post patch delete],
                   spec.dig("paths", "/api2/observations").keys)
    end

    def test_get_query_params_introspected_from_help
      get = spec.dig("paths", "/api2/observations", "get")

      names = get["parameters"].pluck("name")
      assert_includes(names, "date")
      assert_includes(names, "north")
      # Description comes from the param's help: annotation.
      date = get["parameters"].find { |p| p["name"] == "date" }
      assert(date["description"].present?)
    end

    def test_latitude_type_mapping
      get = spec.dig("paths", "/api2/observations", "get")
      north = get["parameters"].find { |p| p["name"] == "north" }

      assert_equal("number", north.dig("schema", "type"))
      assert_equal(-90, north.dig("schema", "minimum"))
    end

    def test_post_has_request_body_with_create_params
      post = spec.dig("paths", "/api2/observations", "post")
      props = post.dig("requestBody", "content", "application/json",
                       "schema", "properties")

      assert(props.key?("name"), "create body should include name")
      assert_equal([{ "api_key" => [] }], post["security"])
    end

    def test_patch_separates_query_from_update_body
      patch = spec.dig("paths", "/api2/observations", "patch")

      assert(patch["parameters"].any?, "patch selects which to update")
      assert(patch.dig("requestBody", "content", "application/json",
                       "schema", "properties").any?)
    end

    def test_every_operation_has_a_response
      spec["paths"].each do |path, ops|
        ops.each do |method, op|
          assert(op["responses"].present?,
                 "#{method.upcase} #{path} has no responses")
        end
      end
    end

    def test_to_yaml_is_alias_free_and_parses
      yaml = API2::OpenapiSpec.to_yaml(resources: [:observation])

      assert_no_match(/ &\d| \*\d/, yaml, "YAML should have no anchors")
      parsed = YAML.safe_load(yaml)
      assert_equal("3.1.0", parsed["openapi"])
    end

    def test_generator_leaves_no_temp_api_keys
      before = APIKey.where(notes: "openapi-spec-generator").count
      API2::OpenapiSpec.generate(resources: [:name])
      after = APIKey.where(notes: "openapi-spec-generator").count

      assert_equal(before, after, "temp keys must be cleaned up")
    end
  end
end
