# frozen_string_literal: true

class Query::Observations < Query
  include Query::Params::AdvancedSearch
  include Query::Params::Filters

  # Commented-out attributes are here so we don't forget they're added
  # via `extra_parameter_declarations` below.
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:date, [:date])
  query_attr(:id_in_set, [Observation])
  query_attr(:by_users, [User])
  query_attr(:has_name, :boolean)
  query_attr(:names, { lookup: [Name],
                       include_synonyms: :boolean,
                       include_subtaxa: :boolean,
                       include_immediate_subtaxa: :boolean,
                       exclude_original_names: :boolean,
                       include_all_name_proposals: :boolean,
                       exclude_consensus: :boolean })
  query_attr(:confidence, [:float])
  query_attr(:needs_naming, User)
  # query_attr(:clade, :string) # content filter
  # query_attr(:lichen, :boolean) # content filter

  query_attr(:is_collection_location, :boolean)
  query_attr(:has_public_lat_lng, :boolean)
  query_attr(:in_box, { north: :float, south: :float,
                        east: :float, west: :float })
  query_attr(:location_undefined, { boolean: [true] })
  query_attr(:locations, [Location])
  query_attr(:within_locations, [Location])
  # query_attr(:region, :string) # content filter

  query_attr(:has_notes, :boolean)
  query_attr(:notes_has, :string)
  query_attr(:has_notes_fields, [:string])
  query_attr(:pattern, :string)
  query_attr(:has_comments, :boolean)
  query_attr(:comments_has, :string)
  query_attr(:has_sequences, :boolean)
  query_attr(:has_field_slips, :boolean)
  # query_attr(:has_specimen, :boolean) # content filter
  # query_attr(:has_images, :boolean) # content filter

  query_attr(:field_slips, [FieldSlip])
  query_attr(:herbaria, [Herbarium])
  query_attr(:herbarium_records, [HerbariumRecord])
  query_attr(:projects, [Project])
  query_attr(:project_lists, [Project])
  query_attr(:species_lists, [SpeciesList])
  # query_attr(:search_name, :string) # advanced search
  # query_attr(:search_where, :string) # advanced search
  # query_attr(:search_user, :string) # advanced search
  # query_attr(:search_content, :string) # advanced search
  query_attr(:image_query, { subquery: :Image })
  query_attr(:location_query, { subquery: :Location })
  query_attr(:name_query, { subquery: :Name })
  query_attr(:sequence_query, { subquery: :Sequence })

  def self.extra_parameter_declarations
    content_filter_parameter_declarations(Observation).
      merge(advanced_search_parameter_declarations)
  end

  # Declare the parameters as model attributes, of custom type `query_param`
  extra_parameter_declarations.each do |param_name, accepts|
    query_attr(param_name, accepts)
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
