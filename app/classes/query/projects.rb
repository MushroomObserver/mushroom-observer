# frozen_string_literal: true

class Query::Projects < Query::Base
  def model
    Project
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      users: [User],
      ids: [Project],
      with_images: { boolean: [true] },
      with_observations: { boolean: [true] },
      with_species_lists: { boolean: [true] },
      with_comments: { boolean: [true] },
      with_summary: :boolean,
      title_has: :string,
      summary_has: :string,
      field_slip_prefix_has: :string,
      comments_has: :string,
      member: User,
      pattern: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_owner_and_time_stamp_conditions
    initialize_association_parameters
    initialize_boolean_parameters
    initialize_search_parameters
    add_ids_condition
    add_pattern_condition
    super
  end

  def initialize_association_parameters
    # No need to add join unless we're applying this condition.
    return unless params[:member]

    add_join(:"user_group_users.members")
    where << "user_group_users.user_id = '#{params[:member]}'"
  end

  def initialize_boolean_parameters
    add_join(:project_images) if params[:with_images]
    add_join(:project_observations) if params[:with_observations]
    add_join(:project_species_lists) if params[:with_species_lists]
    add_join(:comments) if params[:with_comments]
    add_boolean_condition(
      "LENGTH(COALESCE(projects.summary,'')) > 0",
      "LENGTH(COALESCE(projects.summary,'')) = 0",
      params[:with_summary]
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
