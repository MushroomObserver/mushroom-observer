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
  query_attr(:by_users, [User], param_alias: :by_user,
                                redirect_to: :model_index,
                                always_index: false)
  query_attr(:has_name, :boolean)
  query_attr(:names, { lookup: [Name],
                       include_synonyms: :boolean,
                       include_subtaxa: :boolean,
                       include_immediate_subtaxa: :boolean,
                       exclude_original_names: :boolean,
                       include_all_name_proposals: :boolean,
                       exclude_consensus: :boolean })
  # Each of these is a named preset of `names:` options, backed by a
  # same-named Observation scope (Observation::Scopes).
  query_attr(:look_alikes, Name, default_order: :confidence,
                                 always_index: false)
  query_attr(:related_taxa, Name, default_order: :confidence,
                                  always_index: false)
  # param_alias matches the URL shortcut (`?name=`) -- attr itself is
  # `any_name`, not `name`, to avoid colliding with `Observation.name`
  # (see Observation::Scopes#any_name).
  query_attr(:any_name, [:string], param_alias: :name,
                                   default_order: :confidence)
  query_attr(:name_proposed, [:string], default_order: :confidence)
  query_attr(:this_name, [:string], default_order: :confidence)
  query_attr(:other_names, [:string], default_order: :confidence)
  query_attr(:confidence, [:float])
  # A presence flag, not a User id -- Query::Modules::Initialization's
  # apply_scope_param sends `viewer` to the scope, ignoring this value's
  # identity, so the URL can only mean "my queue". `:truthy`, not
  # `:boolean`, so an old `needs_naming: <user_id>` bookmark still
  # resolves to "flag on" instead of failing validation. default_order
  # matches the identify page's default (Observations::IdentifyController).
  query_attr(:needs_naming, :truthy, default_order: :rss_log)
  # query_attr(:clade, :string) # content filter
  # query_attr(:lichen, :boolean) # content filter
  # The identify page's clade/region autocompleter -- see
  # Observation::Scopes#identify_filter. default_order matches the
  # identify page's own default (Observations::IdentifyController).
  query_attr(:identify_filter, { type: :string, term: :string },
             default_order: :rss_log)

  query_attr(:is_collection_location, :boolean)
  query_attr(:has_public_lat_lng, :boolean)
  query_attr(:in_box, { north: :float, south: :float,
                        east: :float, west: :float })
  query_attr(:location_undefined, { boolean: [true] })
  query_attr(:locations, [Location])
  query_attr(:within_locations, [Location], param_alias: :location,
                                            redirect_to: :model_index,
                                            always_index: false)
  # query_attr(:region, :string) # content filter

  query_attr(:has_notes, :boolean)
  query_attr(:notes_has, :string)
  query_attr(:has_notes_fields, [:string])
  query_attr(:pattern, :string)
  query_attr(:has_comments, :boolean)
  query_attr(:comments_has, :string)
  query_attr(:has_sequences, :boolean)
  query_attr(:has_field_slips, :boolean)
  query_attr(:has_collection_numbers, :boolean)
  # query_attr(:has_specimen, :boolean) # content filter
  # query_attr(:has_images, :boolean) # content filter

  query_attr(:herbaria, [Herbarium], param_alias: :herbarium)
  query_attr(:herbarium_records, [HerbariumRecord],
             param_alias: :herbarium_record)
  query_attr(:projects, [Project], param_alias: :project,
                                   redirect_to: :model_index)
  query_attr(:project_lists, [Project], param_alias: :project_list)
  query_attr(:species_lists, [SpeciesList], param_alias: :species_list,
                                            redirect_to: :model_index)
  query_attr(:external_sites, [ExternalSite], param_alias: :external_site)
  # query_attr(:search_name, :string) # advanced search
  # query_attr(:search_where, :string) # advanced search
  # query_attr(:search_user, :string) # advanced search
  # query_attr(:search_content, :string) # advanced search
  query_attr(:inat_import, InatImport)
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

  # ObservationsController::Index's `where` shortcut aliases to this
  # attr -- redeclared (after the loop above) with the alias.
  query_attr(:search_where, :string, param_alias: :where, always_index: true)

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
