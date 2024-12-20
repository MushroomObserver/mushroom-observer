# frozen_string_literal: true

class Query::LocationDescriptionBase < Query::Base
  include Query::Initializers::Descriptions

  def model
    LocationDescription
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      ids?: [LocationDescription],
      by_user?: User,
      by_author?: User,
      by_editor?: User,
      old_by?: :string,
      users?: [User],
      locations?: [Location],
      public?: :boolean
    )
  end

  def initialize_flavor
    add_ids_condition("location_descriptions")
    add_owner_and_time_stamp_conditions("location_descriptions")
    add_by_user_condition("location_descriptions")
    add_by_author_condition
    add_by_editor_condition
    locations = lookup_locations_by_name(params[:locations])
    add_id_condition("location_descriptions.location_id", locations)
    add_boolean_condition(
      "location_descriptions.public IS TRUE",
      "location_descriptions.public IS FALSE",
      params[:public]
    )
    super
  end

  def add_by_author_condition
    return unless params[:by_author]

    user = find_cached_parameter_instance(User, :by_author)
    @title_tag = :query_title_by_author.t(type: :location_description,
                                          user: user.legal_name)
    @title_args[:user] = user.legal_name
    add_join(:location_description_authors)
    where << "location_description_authors.user_id = '#{user.id}'"
  end

  def add_by_editor_condition
    return unless params[:by_editor]

    user = find_cached_parameter_instance(User, :by_editor)
    @title_tag = :query_title_by_editor.t(type: :location_description,
                                          user: user.legal_name)
    @title_args[:user] = user.legal_name
    add_join(:location_description_editors)
    where << "location_description_editors.user_id = '#{user.id}'"
  end

  def self.default_order
    "name"
  end
end
