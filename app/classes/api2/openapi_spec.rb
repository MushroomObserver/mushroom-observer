# frozen_string_literal: true

class API2
  # Generates an OpenAPI 3.1 description of the API2 endpoints.
  #
  # The request side (query/body params, per method) is introspected
  # from the existing API2 `help` mechanism: each endpoint is executed
  # with `help=1`, which raises an `API2::HelpMessage` carrying the
  # declared `ParameterDeclaration`s (name, type, range/list flags,
  # deprecated flag). Descriptions come from the same `help:` annotations
  # the params already carry -- so the one bit of human-authored prose
  # lives next to the code, not in a separate doc that can rot.
  #
  # The response side is hand-wired per resource for now (see
  # ResponseSchemas); capturing full response schemas from the API2
  # test suite is the planned follow-up. XML output is deprecated and is
  # intentionally not described here.
  #
  # Methods a resource does not support (its API2 subclass raises
  # NoMethodForAction) yield no HelpMessage and are omitted from the
  # spec automatically.
  module OpenapiSpec
    module_function

    # action(singular) => url path segment(plural), one per routed
    # api2 resource (config/routes.rb).
    RESOURCES = {
      api_key: "api_keys",
      collection_number: "collection_numbers",
      comment: "comments",
      external_link: "external_links",
      external_site: "external_sites",
      field_slip: "field_slips",
      herbarium: "herbaria",
      herbarium_record: "herbarium_records",
      image: "images",
      location: "locations",
      location_description: "location_descriptions",
      name: "names",
      name_description: "name_descriptions",
      naming: "namings",
      observation: "observations",
      occurrence: "occurrences",
      project: "projects",
      sequence: "sequences",
      species_list: "species_lists",
      user: "users"
    }.freeze

    # Meta params handled globally, not per-endpoint.
    META_PARAMS = [:method, :action, :version, :api_key, :page, :detail,
                   :format].freeze

    # ParameterDeclaration#type => OpenAPI schema fragment.
    TYPE_MAP = {
      string: { "type" => "string" },
      integer: { "type" => "integer" },
      float: { "type" => "number" },
      boolean: { "type" => "boolean" },
      date: { "type" => "string", "format" => "date" },
      time: { "type" => "string", "format" => "date-time" },
      enum: { "type" => "string" },
      email: { "type" => "string", "format" => "email" },
      url: { "type" => "string", "format" => "uri" },
      latitude: { "type" => "number", "minimum" => -90, "maximum" => 90 },
      longitude: { "type" => "number", "minimum" => -180, "maximum" => 180 }
    }.freeze

    # Types that reference another MO record: the API accepts an id (or,
    # often, a name/string). Rendered as a string with a note.
    OBJECT_TYPES = [
      :user, :name, :location, :herbarium, :herbarium_record,
      :project, :species_list, :collection_number, :external_site,
      :image, :comment, :naming, :sequence, :observation, :region,
      :license
    ].freeze

    def generate(resources: RESOURCES.keys)
      {
        "openapi" => "3.1.0",
        "info" => info,
        "servers" => [{ "url" => "https://mushroomobserver.org" }],
        "paths" => build_paths(resources),
        "components" => {
          "securitySchemes" => {
            "api_key" => { "type" => "apiKey", "in" => "query",
                           "name" => "api_key" }
          }
        }
      }
    end

    # Round-trip through JSON so the YAML has no anchors/aliases (Psych
    # emits them for shared fragments; some OpenAPI tools choke on them).
    def to_yaml(resources: RESOURCES.keys)
      JSON.parse(generate(resources: resources).to_json).to_yaml
    end

    def info
      {
        "title" => "Mushroom Observer API",
        "version" => API2.version.to_s,
        "description" =>
          "REST-ish API for creating, reading, and modifying Mushroom " \
          "Observer records. Authentication uses an API key. XML output " \
          "is deprecated and undocumented here; use JSON."
      }
    end

    def build_paths(resources)
      resources.each_with_object({}) do |action, paths|
        path = "/api2/#{RESOURCES.fetch(action)}"
        paths[path] = build_operations(action)
      end
    end

    # ---- operations per resource ------------------------------------

    def build_operations(action)
      ops = {}
      ops["get"] = get_operation(action)
      ops["post"] = post_operation(action)
      ops["patch"] = patch_operation(action)
      ops["delete"] = delete_operation(action)
      ops.compact
    end

    def get_operation(action)
      decls = introspect(action, "GET")
      return nil if decls.nil?

      {
        "summary" => "Search / read #{RESOURCES.fetch(action)}",
        "parameters" => query_parameters(decls),
        "responses" => ok_response(action)
      }
    end

    def post_operation(action)
      decls = introspect(action, "POST", auth: true)
      return nil if decls.blank?

      {
        "summary" => "Create #{action}",
        "security" => [{ "api_key" => [] }],
        "requestBody" => request_body(body_schema(decls)),
        "responses" => ok_response(action)
      }
    end

    def patch_operation(action)
      decls = introspect(action, "PATCH", auth: true)
      return nil if decls.nil?

      updates, query = decls.partition(&:set_parameter?)
      return nil if updates.empty?

      {
        "summary" => "Update #{RESOURCES.fetch(action)}",
        "security" => [{ "api_key" => [] }],
        "parameters" => query_parameters(query),
        "requestBody" => request_body(body_schema(updates)),
        "responses" => ok_response(action)
      }
    end

    def delete_operation(action)
      decls = introspect(action, "DELETE", auth: true)
      return nil if decls.blank?

      {
        "summary" => "Delete #{RESOURCES.fetch(action)}",
        "security" => [{ "api_key" => [] }],
        "parameters" => query_parameters(decls),
        "responses" => { "200" => { "description" => "Deleted" } }
      }
    end

    # ---- param introspection ----------------------------------------

    # Declared, non-meta, non-deprecated params for one endpoint/method,
    # pulled from the HelpMessage the `help` request raises. Returns nil
    # when the endpoint yields no HelpMessage -- i.e. the resource does
    # not support the method (NoMethodForAction raises before help).
    def introspect(action, method, auth: false)
      key = auth ? temp_api_key : nil
      begin
        api = API2.execute({ method: method, action: action.to_s,
                             help: "1", api_key: key&.key }.compact)
        help = api.errors.find { |e| e.is_a?(API2::HelpMessage) }
        return nil unless help

        help.params.values.reject(&:deprecated?).
          reject { |p| META_PARAMS.include?(p.key) }
      ensure
        key&.destroy
      end
    end

    def query_parameters(decls)
      decls.map { |decl| query_parameter(decl) }
    end

    def query_parameter(decl)
      {
        "name" => decl.key.to_s,
        "in" => "query",
        "required" => false,
        "description" => description_for(decl),
        "schema" => param_schema(decl)
      }.compact
    end

    def body_schema(decls)
      props = decls.to_h do |decl|
        [decl.key.to_s, param_schema(decl).
          merge("description" => description_for(decl)).
          compact]
      end
      { "type" => "object", "properties" => props }
    end

    # ---- type mapping -----------------------------------------------

    def param_schema(decl)
      base = base_schema(decl)
      return array_of(base) if decl.args[:list]
      return range_of(base) if decl.args[:range]

      base
    end

    def base_schema(decl)
      return TYPE_MAP[decl.type].dup if TYPE_MAP.key?(decl.type)

      if OBJECT_TYPES.include?(decl.type)
        return { "type" => "string",
                 "description" => "id or name of a #{decl.type}" }
      end

      { "type" => "string" }
    end

    def array_of(base)
      { "type" => "array", "items" => base,
        "description" => "comma-separated list" }
    end

    # MO ranges are submitted as "min-max" (or "min-" / "-max").
    def range_of(_base)
      { "type" => "string",
        "description" => "range, submitted as `min-max`" }
    end

    def description_for(decl)
      help = decl.args[:help]
      return nil if help.nil?

      tag = help == 1 ? decl.key : help
      # Symbol#l returns the key itself for a missing translation.
      value = :"api_help_#{tag}".l
      value.to_s.start_with?("api_help_") ? nil : value
    end

    # ---- responses (hand-wired for the PoC) -------------------------

    def request_body(schema)
      { "required" => true,
        "content" => { "application/json" => { "schema" => schema } } }
    end

    def ok_response(action)
      {
        "200" => {
          "description" => "Matching #{RESOURCES.fetch(action)}",
          "content" => { "application/json" => {
            "schema" => results_envelope(action)
          } }
        }
      }
    end

    def results_envelope(action)
      {
        "type" => "object",
        "properties" => {
          "results" => {
            "type" => "array",
            "items" => ResponseSchemas::SCHEMAS.fetch(action)
          }
        }
      }
    end

    # A verified, throwaway key so write-method help gets past
    # authentication (the help raises before any object is written).
    def temp_api_key(user: User.first)
      key = APIKey.create!(user: user, notes: "openapi-spec-generator")
      key.update_columns(verified: Time.zone.now)
      key
    end
  end
end
