# frozen_string_literal: true

class Query::LocationWithDescriptions < Query::LocationBase
  def parameter_declarations
    super.merge(
      ids?: [LocationDescription]
    ).merge(descriptions_coercion_parameter_declarations)
  end

  def initialize_flavor
    add_join(:location_descriptions)
    add_ids_condition
    add_by_user_condition
    add_by_author_condition
    add_by_editor_condition
    super
  end

  def add_ids_condition
    return unless params[:ids]

    @title_tag = :query_title_with_descriptions.t(type: :location)
    @title_args[:descriptions] = params[:old_title] ||
                                 :query_title_in_set.t(type: :description)
    initialize_in_set_flavor("location_descriptions")
  end

  def add_by_user_condition
    return unless params[:by_user]

    user = find_cached_parameter_instance(User, :by_user)
    @title_tag = :query_title_with_descriptions_by_user.t(type: :location)
    @title_args[:user] = user.legal_name
    add_join(:location_descriptions)
    where << "location_descriptions.user_id = '#{user.id}'"
  end

  def add_by_author_condition
    return unless params[:by_author]

    user = find_cached_parameter_instance(User, :by_author)
    @title_tag = :query_title_with_descriptions_by_author.t(type: :location)
    @title_args[:user] = user.legal_name
    add_join(:location_descriptions, :location_description_authors)
    where << "location_description_authors.user_id = '#{user.id}'"
  end

  def add_by_editor_condition
    return unless params[:by_editor]

    user = find_cached_parameter_instance(User, :by_editor)
    @title_tag = :query_title_with_descriptions_by_editor.t(type: :location)
    @title_args[:user] = user.legal_name
    add_join(:location_descriptions, :location_description_editors)
    where << "location_description_editors.user_id = '#{user.id}'"
  end

  def coerce_into_location_description_query
    Query.lookup(:LocationDescription, :all, params_with_old_by_restored)
  end
end
