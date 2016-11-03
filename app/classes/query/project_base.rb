class Query::ProjectBase < Query::Base
  def model
    Project
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      users?: [User],
      has_images?: { string: [:yes] },
      has_observations?: { string: [:yes] },
      has_species_lists?: { string: [:yes] },
      has_comments?: { string: [:yes] },
      has_notes?: :boolean,
      title_has?: :string,
      notes_has?: :string,
      comments_has?: :string
    )
  end

  def initialize_flavor
    initialize_model_do_time(:created_at)
    initialize_model_do_time(:updated_at)
    initialize_model_do_objects_by_id(:users)
    add_join(:images_projects) if params[:has_images]
    add_join(:observations_projects) if params[:has_observations]
    add_join(:projects_species_lists) if params[:has_species_lists]
    initialize_model_do_search(:title_has, :title)
    initialize_model_do_search(:notes_has, :notes)
    initialize_model_do_boolean(:has_notes,
                                'LENGTH(COALESCE(species_lists.notes,"")) > 0',
                                'LENGTH(COALESCE(species_lists.notes,"")) = 0'
                               )
    add_join(:comments) if params[:has_comments]
    unless params[:comments_has].blank?
      initialize_model_do_search(:comments_has,
                                 "CONCAT(comments.summary,comments.notes)")
      add_join(:comments)
    end
    super
  end

  def default_order
    "title"
  end
end
