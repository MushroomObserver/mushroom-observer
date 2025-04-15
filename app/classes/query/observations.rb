# frozen_string_literal: true

class Query::Observations < Query::Base
  include Query::Params::AdvancedSearch
  include Query::Params::Filters

  def self.parameter_declarations # rubocop:disable Metrics/MethodLength
    super.merge(
      date: [:date],
      created_at: [:time],
      updated_at: [:time],

      id_in_set: [Observation],
      by_users: [User],
      has_name: :boolean,
      names: { lookup: [Name],
               include_synonyms: :boolean,
               include_subtaxa: :boolean,
               include_immediate_subtaxa: :boolean,
               exclude_original_names: :boolean,
               include_all_name_proposals: :boolean,
               exclude_consensus: :boolean },
      confidence: [:float],
      needs_naming: User,
      # clade: :string, # content_filter
      # lichen: :boolean, # content_filter

      is_collection_location: :boolean,
      has_public_lat_lng: :boolean,
      location_undefined: { boolean: [true] },
      locations: [Location],
      in_box: { north: :float, south: :float, east: :float, west: :float },
      # region: :string, # content filter

      has_notes: :boolean,
      notes_has: :string,
      has_notes_fields: [:string],
      pattern: :string,
      has_comments: { boolean: [true] },
      comments_has: :string,
      has_sequences: { boolean: [true] },
      # has_specimen: :boolean, # content filter
      # has_images: :boolean, # content filter

      field_slips: [FieldSlip],
      herbaria: [Herbarium],
      herbarium_records: [HerbariumRecord],
      projects: [Project],
      project_lists: [Project],
      species_lists: [SpeciesList],
      image_query: { subquery: :Image },
      location_query: { subquery: :Location },
      name_query: { subquery: :Name },
      sequence_query: { subquery: :Sequence }
    ).merge(content_filter_parameter_declarations(Observation)).
      merge(advanced_search_parameter_declarations)
  end

  # Declare the parameters as model attributes, of custom type `query_param`
  parameter_declarations.each do |param_name, accepts|
    attribute param_name, :query_param, accepts: accepts
  end

  def model
    @model ||= Observation
  end

  def alphabetical_by
    @alphabetical_by ||= case params[:order_by].to_s
                         when "user", "reverse_user"
                           User[:login]
                         when "name", "reverse_name"
                           Name[:sort_name]
                         end
  end

  def self.default_order
    :date
  end
end
