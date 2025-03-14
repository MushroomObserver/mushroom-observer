# frozen_string_literal: true

module Query::Initializers::Descriptions
  def initialize_description_public_parameter(type)
    add_boolean_condition(
      "#{type}_descriptions.public IS TRUE",
      "#{type}_descriptions.public IS FALSE",
      params[:is_public]
    )
  end

  def add_desc_by_author_condition(type)
    return unless params[:by_author]

    # Change this conditional to check for :has_descriptions param
    with_desc = with_desc_string
    user = find_cached_parameter_instance(User, :by_author)
    @title_tag = :"query_title#{with_desc}_by_author".t(
      type: :"#{type}_description", user: user.legal_name
    )
    @title_args[:user] = user.legal_name
    add_join(:"#{type}_descriptions", :"#{type}_description_authors")
    where << "#{type}_description_authors.user_id = '#{user.id}'"
  end

  def add_desc_by_editor_condition(type)
    return unless params[:by_editor]

    # Change this conditional to check for :has_descriptions param
    with_desc = with_desc_string
    user = find_cached_parameter_instance(User, :by_editor)
    @title_tag = :"query_title#{with_desc}_by_editor".t(
      type: :"#{type}_description", user: user.legal_name
    )
    @title_args[:user] = user.legal_name
    add_join(:"#{type}_descriptions", :"#{type}_description_editors")
    where << "#{type}_description_editors.user_id = '#{user.id}'"
  end

  def with_desc_string
    [Name, Location].include?(model) ? "_has_descriptions" : ""
  end

  # If ever generalizing, `type` should be model.parent_type
  def initialize_name_descriptions_parameters(type = "name")
    initialize_ok_for_export_parameter
    initialize_sources_parameter(type)
    initialize_projects_parameter(:"#{type}_descriptions", nil)
    initialize_content_has_parameter(type)
  end

  def initialize_sources_parameter(type)
    add_indexed_enum_condition(
      "#{type}_descriptions.source_type",
      params[:sources],
      "#{type}_description".classify.constantize.source_types # Hash
    )
  end

  def initialize_content_has_parameter(type)
    model = "#{type}_descriptions".classify.constantize
    fields = model.all_note_fields
    fields = fields.map { |f| "COALESCE(#{type}_descriptions.#{f},'')" }
    fields = "CONCAT(#{fields.join(",")})"
    add_search_condition(fields, params[:content_has])
  end
end
