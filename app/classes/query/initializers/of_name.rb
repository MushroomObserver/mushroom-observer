module Query::Initializers::OfName
  def of_name_parameter_declarations
    {
      name:          :name,
      synonyms?:     { string: [:no, :all, :exclusive] },
      nonconsensus?: { string: [:no, :all, :exclusive] },
      project?:      Project,
      species_list?: SpeciesList,
      user?:         User
    }
  end

  def give_parameter_defaults
    params[:synonyms]     ||= :no
    params[:nonconsensus] ||= :no
  end

  def get_target_names
    if name = get_cached_parameter_instance(:name)
      names = [name]
    else
      name = params[:name]
      if name.is_a?(Fixnum) || name.match(/^\d+$/)
        names = [Name.find(name.to_i)]
      else
        names = Name.where(search_name: name)
        names = Name.where(text_name: name) if names.empty?
      end
    end
    names
  end

  def get_corresponding_name_ids(names)
    if params[:synonyms] == :no
      name_ids = names.map(&:id) + names.map(&:misspelling_ids).flatten
    elsif params[:synonyms] == :all
      name_ids = names.map(&:synonym_ids).flatten
    elsif params[:synonyms] == :exclusive
      name_ids = names.map(&:synonym_ids).flatten - names.map(&:id) - names.map(&:misspelling_ids).flatten
    else
      fail "Invalid synonym inclusion mode: '#{synonyms}'"
    end
    clean_id_set(name_ids.uniq)
  end   

  def choose_a_title(names)
    title_args[:tag] = :query_title_of_name
    title_args[:tag] = :query_title_of_name_synonym      if params[:synonyms] != :no
    title_args[:tag] = :query_title_of_name_nonconsensus if params[:nonconsensus] != :no
    title_args[:name] = names.length == 1 ? names.first.display_name : params[:name]
  end

  def add_name_conditions(names)
    id_set = get_corresponding_name_ids(names)
    if params[:nonconsensus] == :no
      self.where << "observations.name_id IN (#{id_set}) AND " \
                    "COALESCE(observations.vote_cache,0) >= 0"
      self.order = "COALESCE(observations.vote_cache,0) DESC, observations.when DESC"
    elsif params[:nonconsensus] == :all
      self.where << "namings.name_id IN (#{id_set})"
      self.order = "COALESCE(namings.vote_cache,0) DESC, observations.when DESC"
      add_join_to_observations(:namings)
    elsif params[:nonconsensus] == :exclusive
      self.where << "namings.name_id IN (#{id_set}) AND " \
                    "(observations.name_id NOT IN (#{id_set}) OR " \
                    "COALESCE(observations.vote_cache,0) < 0)"
      self.order = "COALESCE(namings.vote_cache,0) DESC, observations.when DESC"
      add_join_to_observations(:namings)
    else
      fail "Invalid nonconsensus inclusion mode: '#{params[:nonconsensus]}'"
    end
  end

  def restrict_to_one_project
    if params[:project]
      project = find_cached_parameter_instance(Project, :project)
      self.where << "observations_projects.project_id = #{project.id}"
      add_join_to_observations(:observations_projects)
    end
  end

  def restrict_to_one_species_list
    if params[:species_list]
      species_list = find_cached_parameter_instance(SpeciesList, :species_list)
      self.where << "observations_species_lists.species_list_id = #{species_list.id}"
      add_join_to_observations(:observations_species_lists)
    end
  end

  def restrict_to_one_user
    if params[:user]
      user = find_cached_parameter_instance(User, :user)
      self.where << "observations.user_id = #{user.id}"
    end
  end
end
