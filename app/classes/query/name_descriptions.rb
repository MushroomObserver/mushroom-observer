# frozen_string_literal: true

class Query::NameDescriptions < Query::Base
  # include Query::Params::Descriptions
  # include Query::Params::Names
  include Query::Initializers::Descriptions

  def model
    NameDescription
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      ids: [NameDescription],
      by_user: User,
      by_author: User,
      by_editor: User,
      # old_by: :string,
      users: [User],
      names: [Name],
      name_query: { subquery: :Name },
      public: :boolean,
      # with_default_desc: :boolean,
      join_desc: { string: [:default, :any] },
      desc_type: [{ string: Description::ALL_SOURCE_TYPES }],
      desc_project: [Project],
      desc_creator: [User],
      desc_content: :string,
      ok_for_export: :boolean
      # with_descriptions: :boolean
    ) # .merge(name_descriptions_parameter_declarations)
  end

  def initialize_flavor
    add_sort_order_to_title
    add_ids_condition
    add_owner_and_time_stamp_conditions
    add_by_user_condition
    add_desc_by_author_condition(:name)
    add_desc_by_editor_condition(:name)
    add_id_condition("name_descriptions.name_id", params[:names])
    initialize_description_public_parameter(:name)
    initialize_name_descriptions_parameters
    add_subquery_condition(:name_query, :names)
    super
  end

  # def coerce_into_name_query
  #   pargs = params_out_to_with_descriptions_params
  #   Query.lookup(:Name, pargs)
  # end

  def self.default_order
    "name"
  end
end
