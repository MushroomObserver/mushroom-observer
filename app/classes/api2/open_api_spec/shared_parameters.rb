# frozen_string_literal: true

class API2
  module OpenAPISpec
    # Global params (parsed for every endpoint in API2#parse_core_params)
    # documented once in components.parameters and $ref'd from each
    # operation that returns records.
    module SharedParameters
      DEFS = {
        "detail" => {
          "name" => "detail",
          "in" => "query",
          "required" => false,
          "description" =>
            "response detail level: `none` (the default) returns " \
            "matching ids only; `low` returns the top-level fields " \
            "documented here; `high` adds nested objects (owner, " \
            "images, namings and votes, comments, etc.)",
          "schema" => { "type" => "string", "enum" => %w[none low high],
                        "default" => "none" }
        },
        "page" => {
          "name" => "page",
          "in" => "query",
          "required" => false,
          "description" => "page of results to return, starting at 1",
          "schema" => { "type" => "integer", "default" => 1 }
        }
      }.freeze
    end
  end
end
