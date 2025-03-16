# frozen_string_literal: true

class Query::Projects < Query::Base
  def model
    Project
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [Project],
      by_users: [User],
      members: [User],
      title_has: :string,
      has_summary: :boolean,
      summary_has: :string,
      field_slip_prefix_has: :string,
      has_images: { boolean: [true] },
      has_observations: { boolean: [true] },
      has_species_lists: { boolean: [true] },
      has_comments: { boolean: [true] },
      comments_has: :string,
      pattern: :string
    )
  end

  def initialize_flavor
    add_owner_and_time_stamp_conditions
    initialize_association_parameters
    initialize_boolean_parameters
    initialize_search_parameters
    add_id_in_set_condition
    add_pattern_condition
    super
  end

  def initialize_association_parameters
    # No need to add join unless we're applying this condition.
    return unless params[:members]

    # add_join(:"user_group_users.members")
    # where << "user_group_users.user_id = '#{params[:member]}'"
    ids = lookup_users_by_name(params[:members])
    add_association_condition(
      "user_group_users.user_id", ids, :"user_group_users.members"
    )
  end

  def initialize_boolean_parameters
    add_join(:project_images) if params[:has_images]
    add_join(:project_observations) if params[:has_observations]
    add_join(:project_species_lists) if params[:has_species_lists]
    add_join(:comments) if params[:has_comments]
    add_boolean_condition(
      "LENGTH(COALESCE(projects.summary,'')) > 0",
      "LENGTH(COALESCE(projects.summary,'')) = 0",
      params[:has_summary]
    )
  end

  def initialize_search_parameters
    add_search_condition("projects.title", params[:title_has])
    add_search_condition("projects.summary", params[:summary_has])
    add_search_condition(
      "projects.field_slip_prefix",
      params[:field_slip_prefix_has]
    )
    add_search_condition(
      "CONCAT(comments.summary,COALESCE(comments.comment,''))",
      params[:comments_has],
      :comments
    )
  end

  def search_fields
    "CONCAT(" \
      "projects.title," \
      "COALESCE(projects.summary,'')," \
      "COALESCE(projects.field_slip_prefix,'')" \
      ")"
  end

  def self.default_order
    "updated_at"
  end
end
