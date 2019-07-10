class Query::ProjectBase < Query::Base
  def model
    Project
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      users?: [User],
      has_images?: { boolean: [true] },
      has_observations?: { boolean: [true] },
      has_species_lists?: { boolean: [true] },
      has_comments?: { boolean: [true] },
      has_summary?: :boolean,
      title_has?: :string,
      summary_has?: :string,
      comments_has?: :string
    )
  end

  def initialize_flavor
    add_owner_and_time_stamp_conditions("projects")
    initialize_boolean_parameters
    initialize_search_parameters
    super
  end

  def initialize_boolean_parameters
    add_join(:images_projects) if params[:has_images]
    add_join(:observations_projects) if params[:has_observations]
    add_join(:projects_species_lists) if params[:has_species_lists]
    add_join(:comments) if params[:has_comments]
    add_boolean_condition(
      "LENGTH(COALESCE(projects.summary,'')) > 0",
      "LENGTH(COALESCE(projects.summary,'')) = 0",
      params[:has_summary]
    )
  end

  def initialize_search_parameters
    add_search_condition(
      "projects.title",
      params[:title_has]
    )
    add_search_condition(
      "projects.summary",
      params[:summary_has]
    )
    add_search_condition(
      "CONCAT(comments.summary,COALESCE(comments.comment,''))",
      params[:comments_has],
      :comments
    )
  end

  def default_order
    "title"
  end
end
