# frozen_string_literal: true

# see app/controllers/species_lists_controller.rb
class SpeciesListsController

  ##############################################################################
  #
  #  :section: Manage projects
  #
  ##############################################################################

  # TODO: NIMMO is this another REST controller here?
  # SpeciesList::ProjectsController

  def manage_projects # :norobots:
    @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    return unless (@species_list)

    if !check_permission!(@species_list)
      redirect_to species_list_path(@species_list.id)
    else
      @projects = projects_to_manage
      @object_states = manage_object_states
      @project_states = manage_project_states
      if request.method == "POST"
        if params[:commit] == :ATTACH.l
          if attach_objects_to_projects
            redirect_to species_list_path(@species_list.id)
          else
            flash_warning(:runtime_no_changes.t)
          end
        elsif params[:commit] == :REMOVE.l
          if remove_objects_from_projects
            redirect_to species_list_path(@species_list.id)
          else
            flash_warning(:runtime_no_changes.t)
          end
        else
          flash_error("Invalid submit button: #{params[:commit].inspect}")
        end
      end
    end
  end

  def projects_to_manage
    projects = @user.projects_member
    if @species_list.user == @user
      projects += @species_list.projects
      projects.uniq!
    end
    projects
  end

  def manage_object_states
    {
      list: params[:objects_list].present?,
      obs: params[:objects_obs].present?,
      img: params[:objects_img].present?
    }
  end

  def manage_project_states
    states = {}
    @projects.each do |proj|
      states[proj.id] = params["projects_#{proj.id}"].present?
    end
    states
  end

  def attach_objects_to_projects
    @any_changes = false
    @projects.each do |proj|
      if @project_states[proj.id]
        if !@user.projects_member.include?(proj)
          flash_error(:species_list_projects_no_add_to_project.
                         t(proj: proj.title))
        else
          attach_species_list_to_project(proj) if @object_states[:list]
          attach_observations_to_project(proj) if @object_states[:obs]
          attach_images_to_project(proj)       if @object_states[:img]
        end
      end
    end
    @any_changes
  end

  def remove_objects_from_projects
    @any_changes = false
    @projects.each do |proj|
      next unless @project_states[proj.id]

      remove_species_list_from_project(proj) if @object_states[:list]
      remove_observations_from_project(proj) if @object_states[:obs]
      remove_images_from_project(proj)       if @object_states[:img]
    end
    @any_changes
  end

  def attach_species_list_to_project(proj)
    return if @species_list.projects.include?(proj)

    proj.add_species_list(@species_list)
    flash_notice(:attached_to_project.
                    t(object: :species_list, project: proj.title))
    @any_changes = true
  end

  def remove_species_list_from_project(proj)
    return unless @species_list.projects.include?(proj)

    proj.remove_species_list(@species_list)
    flash_notice(:removed_from_project.
                    t(object: :species_list, project: proj.title))
    @any_changes = true
  end

  def attach_observations_to_project(proj)
    obs = @species_list.observations.select { |o| check_permission(o) }
    obs -= proj.observations
    return unless obs.any?

    proj.add_observations(obs)
    flash_notice(:attached_to_project.
                    t(object: "#{obs.length} #{:observations.l}",
                      project: proj.title))
    @any_changes = true
  end

  def remove_observations_from_project(proj)
    obs = @species_list.observations.select { |o| check_permission(o) }
    unless @user.projects_member.include?(proj)
      obs.select! { |o| o.user == @user }
    end
    obs &= proj.observations
    return unless obs.any?

    proj.remove_observations(obs)
    flash_notice(:removed_from_project.
                    t(object: "#{obs.length} #{:observations.l}",
                      project: proj.title))
    @any_changes = true
  end

  def attach_images_to_project(proj)
    imgs = @species_list.observations.map(&:images).flatten.uniq.
           select { |i| check_permission(i) }
    imgs -= proj.images
    return unless imgs.any?

    proj.add_images(imgs)
    flash_notice(:attached_to_project.
                    t(object: "#{imgs.length} #{:images.l}",
                      project: proj.title))
    @any_changes = true
  end

  def remove_images_from_project(proj)
    imgs = @species_list.observations.map(&:images).flatten.uniq.
           select { |i| check_permission(i) }
    unless @user.projects_member.include?(proj)
      imgs.select! { |i| i.user == @user }
    end
    imgs &= proj.observations
    return unless imgs.any?

    proj.remove_images(imgs)
    flash_notice(:removed_from_project.
                    t(object: "#{imgs.length} #{:images.l}",
                      project: proj.title))
    @any_changes = true
  end

end
