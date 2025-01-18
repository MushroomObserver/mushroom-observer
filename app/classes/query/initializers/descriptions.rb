# frozen_string_literal: true

module Query::Initializers::Descriptions
  def initialize_description_public_parameter(type)
    add_boolean_condition(
      "#{type}_descriptions.public IS TRUE",
      "#{type}_descriptions.public IS FALSE",
      params[:public]
    )
  end

  def initialize_with_desc_basic_parameters(type = model.type_tag)
    add_with_desc_ids_condition(type)
    add_desc_by_user_condition(type)
    add_desc_by_author_condition(type)
    add_desc_by_editor_condition(type)
  end

  def add_with_desc_ids_condition(type = model.type_tag)
    return unless params[:desc_ids]

    set = clean_id_set(params[:desc_ids])
    @where << "#{type}_descriptions.id IN (#{set})"
    self.order = "FIND_IN_SET(#{type}_descriptions.id,'#{set}') ASC"

    @title_tag = :query_title_with_descriptions.t(type: type)
    @title_args[:descriptions] = params[:old_title] ||
                                 :query_title_in_set.t(type: :description)
  end

  def add_desc_by_user_condition(type)
    return unless params[:by_user]

    user = find_cached_parameter_instance(User, :by_user)
    @title_tag = :query_title_with_descriptions_by_user.t(type: type)
    @title_args[:user] = user.legal_name
    add_join(:"#{type}_descriptions")
    where << "#{type}_descriptions.user_id = '#{user.id}'"
  end

  def add_desc_by_author_condition(type)
    return unless params[:by_author]

    # Change this conditional to check for :with_descriptions param
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

    # Change this conditional to check for :with_descriptions param
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
    [Name, Location].include?(model) ? "_with_descriptions" : ""
  end

  # If ever generalizing, `type` should be model.parent_type
  def initialize_name_descriptions_parameters(type = "name")
    initialize_ok_for_export_parameter
    initialize_with_default_desc_parameter(type)
    initialize_join_desc_parameter(type)
    initialize_desc_type_parameter(type)
    # NOTE: (AN 2025) These may now be superfluous, unless they need to be
    # differentiated from Names parameters sent in the same request. I.e.,
    # they could just use `add_for_project_condition` `add_by_user_condition`
    initialize_desc_project_parameter(type)
    initialize_desc_creator_parameter(type)
    # This is a description notes content search
    initialize_desc_content_parameter(type)
  end

  def initialize_with_default_desc_parameter(type)
    add_boolean_condition(
      "#{type}s.description_id IS NOT NULL",
      "#{type}s.description_id IS NULL",
      params[:with_default_desc]
    )
  end

  def initialize_join_desc_parameter(type)
    if params[:join_desc] == :default
      add_join(:"#{type}_descriptions.default")
    elsif any_param_desc_fields?
      add_join(:"#{type}_descriptions")
    end
  end

  def initialize_desc_type_parameter(type)
    add_indexed_enum_condition(
      "#{type}_descriptions.source_type",
      params[:desc_type],
      "#{type}_description".classify.constantize.source_types # Hash
    )
  end

  def initialize_desc_project_parameter(type)
    add_id_condition(
      "#{type}_descriptions.project_id",
      lookup_projects_by_name(params[:desc_project])
    )
  end

  def initialize_desc_creator_parameter(type)
    add_id_condition(
      "#{type}_descriptions.user_id",
      lookup_users_by_name(params[:desc_creator])
    )
  end

  def initialize_desc_content_parameter(type)
    model = "#{type}_descriptions".classify.constantize
    fields = model.all_note_fields
    fields = fields.map { |f| "COALESCE(#{type}_descriptions.#{f},'')" }
    fields = "CONCAT(#{fields.join(",")})"
    add_search_condition(fields, params[:desc_content])
  end

  def params_out_to_with_descriptions_params
    pargs = params_plus_old_by.merge(with_descriptions: true)
    return pargs if pargs[:ids].blank?

    pargs[:desc_ids] = pargs.delete(:ids)
    pargs
  end

  def params_back_to_description_params
    pargs = params_with_old_by_restored.except(:with_descriptions)
    return pargs if pargs[:desc_ids].blank?

    pargs[:ids] = pargs.delete(:desc_ids)
    pargs
  end

  # --------------------------------------------------------------------------

  private

  def any_param_desc_fields?
    params[:join_desc] == :any ||
      params[:desc_type].present? ||
      params[:desc_project].present? ||
      params[:desc_creator].present? ||
      params[:desc_content].present?
  end
end
