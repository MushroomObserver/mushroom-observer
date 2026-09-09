# frozen_string_literal: true

class API2
  module OpenapiSpec
    # Representative top-level response fields per resource, hand-wired
    # from the non-detail branches of the jbuilder partials
    # (app/views/controllers/api2/_*.json.jbuilder). Capturing full
    # detail schemas from the API2 test suite is the planned follow-up.
    module ResponseSchemas
      module_function

      FIELD_TYPES = {
        integer: { "type" => "integer" },
        string: { "type" => "string" },
        number: { "type" => "number" },
        boolean: { "type" => "boolean" },
        date: { "type" => "string", "format" => "date" },
        datetime: { "type" => "string", "format" => "date-time" },
        uri: { "type" => "string", "format" => "uri" },
        object: { "type" => "object" },
        integer_list: { "type" => "array",
                        "items" => { "type" => "integer" } },
        string_list: { "type" => "array", "items" => { "type" => "string" } },
        object_list: { "type" => "array", "items" => { "type" => "object" } }
      }.freeze

      def object_of(fields)
        { "type" => "object",
          "properties" => fields.to_h do |name, type|
            [name.to_s, FIELD_TYPES.fetch(type)]
          end }
      end

      # The results.json.jbuilder envelope every 200 response is wrapped
      # in. `results` holds ids at detail=none, the SCHEMAS objects at
      # low, and their nested-detail variants at high.
      ENVELOPE_FIELDS = {
        "version" => { "type" => "number" },
        "run_date" => { "type" => "string", "format" => "date-time" },
        "user" => { "type" => "integer" },
        "query" => { "type" => "string" },
        "number_of_records" => { "type" => "integer" },
        "number_of_pages" => { "type" => "integer" },
        "page_number" => { "type" => "integer" },
        "run_time" => { "type" => "number" }
      }.freeze

      def envelope(action)
        {
          "type" => "object",
          "properties" => ENVELOPE_FIELDS.merge(
            "results" => {
              "description" =>
                "matching ids at `detail=none` (the default); the " \
                "objects documented here at `low`, with nested detail " \
                "at `high`",
              "type" => "array",
              "items" => { "oneOf" => [{ "type" => "integer" },
                                       SCHEMAS.fetch(action)] }
            }
          )
        }
      end

      SCHEMAS = {
        api_key: object_of(
          id: :integer, type: :string, key: :string, notes: :string,
          created_at: :datetime, last_used: :datetime, verified: :datetime,
          num_uses: :integer
        ),
        collection_number: object_of(
          id: :integer, type: :string, collector: :string, number: :string,
          created_at: :datetime, updated_at: :datetime, user_id: :integer
        ),
        comment: object_of(
          id: :integer, type: :string, summary: :string, content: :string,
          created_at: :datetime, updated_at: :datetime, object_type: :string,
          object_id: :integer, owner_id: :integer
        ),
        external_link: object_of(
          id: :integer, type: :string, url: :uri, external_id: :string,
          created_at: :datetime, updated_at: :datetime,
          observation_id: :integer, owner_id: :integer,
          external_site_id: :integer
        ),
        external_site: object_of(
          id: :integer, type: :string, name: :string, project_id: :integer
        ),
        field_slip: object_of(
          id: :integer, type: :string, code: :string, created_at: :datetime,
          updated_at: :datetime, observation_ids: :integer_list,
          project_id: :integer, user_id: :integer
        ),
        herbarium: object_of(
          id: :integer, type: :string, code: :string, name: :string,
          email: :string, address: :string, description: :string,
          created_at: :datetime, updated_at: :datetime,
          location_id: :integer, personal_user_id: :integer
        ),
        herbarium_record: object_of(
          id: :integer, type: :string, initial_determination: :string,
          accession_number: :string, notes: :string, created_at: :datetime,
          updated_at: :datetime, herbarium_id: :integer, user_id: :integer
        ),
        image: object_of(
          id: :integer, type: :string, date: :date, copyright_holder: :string,
          notes: :string, quality: :number, created_at: :datetime,
          updated_at: :datetime, original_name: :string,
          number_of_views: :integer, last_viewed: :datetime,
          ok_for_export: :boolean, license: :string, content_type: :string,
          md5sum: :string, width: :integer, height: :integer,
          original_url: :uri, owner_id: :integer
        ),
        location: object_of(
          id: :integer, type: :string, name: :string,
          latitude_north: :number, latitude_south: :number,
          longitude_east: :number, longitude_west: :number,
          altitude_maximum: :number, altitude_minimum: :number,
          notes: :string, created_at: :datetime, updated_at: :datetime,
          number_of_views: :integer, last_viewed: :datetime,
          ok_for_export: :boolean
        ),
        location_description: object_of(
          id: :integer, type: :string, location_id: :integer,
          created_at: :datetime, updated_at: :datetime,
          number_of_views: :integer, last_viewed: :datetime,
          ok_for_export: :boolean, source_type: :string,
          source_name: :string, license: :string, public: :boolean,
          locale: :string, gen_desc: :string, ecology: :string,
          species: :string, notes: :string, refs: :string
        ),
        name: object_of(
          id: :integer, type: :string, name: :string, author: :string,
          rank: :string, deprecated: :boolean, misspelled: :boolean,
          citation: :string, notes: :string, created_at: :datetime,
          updated_at: :datetime, number_of_views: :integer,
          last_viewed: :datetime, ok_for_export: :boolean,
          parents: :object_list, synonym_id: :integer
        ),
        name_description: object_of(
          id: :integer, type: :string, name_id: :integer,
          created_at: :datetime, updated_at: :datetime,
          number_of_views: :integer, last_viewed: :datetime,
          ok_for_export: :boolean, source_type: :string,
          source_name: :string, license: :string, public: :boolean,
          locale: :string, gen_desc: :string, diag_desc: :string,
          distribution: :string, habitat: :string, look_alikes: :string,
          uses: :string, notes: :string, refs: :string,
          classification: :string
        ),
        naming: object_of(
          id: :integer, type: :string, confidence: :number,
          created_at: :datetime, updated_at: :datetime, name: :object,
          owner_id: :integer, observation_id: :integer,
          reasons: :object_list
        ),
        observation: object_of(
          id: :integer, type: :string, date: :date, latitude: :number,
          longitude: :number, altitude: :number, gps_hidden: :boolean,
          specimen_available: :boolean, occurrence_id: :integer,
          is_collection_location: :boolean, confidence: :number,
          notes: :string, notes_fields: :object, created_at: :datetime,
          updated_at: :datetime, number_of_views: :integer,
          last_viewed: :datetime, owner_id: :integer,
          consensus_id: :integer, consensus_name: :string,
          location_id: :integer, location_name: :string,
          primary_image_id: :integer
        ),
        occurrence: object_of(
          id: :integer, type: :string, primary_observation_id: :integer,
          has_specimen: :boolean, created_at: :datetime,
          updated_at: :datetime, observation_ids: :integer_list,
          owner_id: :integer, field_slip_id: :integer
        ),
        project: object_of(
          id: :integer, type: :string, title: :string, summary: :string,
          created_at: :datetime, updated_at: :datetime, creator_id: :integer
        ),
        sequence: object_of(
          id: :integer, type: :string, locus: :string, bases: :string,
          archive: :string, accession: :string, notes: :string,
          created_at: :datetime, updated_at: :datetime,
          observation_id: :integer, user_id: :integer
        ),
        species_list: object_of(
          id: :integer, type: :string, title: :string, notes: :string,
          date: :date, created_at: :datetime, updated_at: :datetime,
          owner_id: :integer, location_id: :integer, location_name: :string
        ),
        user: object_of(
          id: :integer, type: :string, login_name: :string,
          legal_name: :string, joined: :datetime, verified: :datetime,
          last_login: :datetime, last_activity: :datetime,
          contribution: :integer, notes: :string,
          notes_template: :string_list, mailing_address: :string,
          location_id: :integer, image_id: :integer
        )
      }.freeze
    end
  end
end
