# frozen_string_literal: true

module SpeciesLists
  class ProjectsController < ApplicationController
    before_action :login_required

    # ----------------------------
    #  :section: Manage Projects
    # ----------------------------

    # def manage_projects
    def edit
      return unless (@list = find_species_list!)

      if check_permission!(@list)
        @projects = projects_to_manage
        @object_states = manage_object_states
        @project_states = manage_project_states
      else
        redirect_to(species_list_path(@list.id))
      end
    end

    def update
      return unless (@list = find_species_list!)

      if check_permission!(@list)
        @projects = projects_to_manage
        @object_states = manage_object_states
        @project_states = manage_project_states
        commit_and_redirect
      else
        redirect_to(species_list_path(@list.id))
      end
    end

    ############################################################################

    private

    def projects_to_manage
      if @list.user == @user
        @user.projects_member.union(@list.projects)
      else
        @user.projects_member
      end
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

    def commit_and_redirect
      case params[:commit]
      when :ATTACH.l
        if attach_objects_to_projects
          redirect_to(species_list_path(@list.id)) and return
        end

        flash_warning(:runtime_no_changes.t)
      when :REMOVE.l
        if remove_objects_from_projects
          redirect_to(species_list_path(@list.id)) and return
        end

        flash_warning(:runtime_no_changes.t)

      else
        flash_error("Invalid submit button: #{params[:commit].inspect}")
      end
      render(:edit)
    end

    def attach_objects_to_projects
      @any_changes = false
      @projects.each do |proj|
        if @project_states[proj.id]
          if @user.projects_member.exclude?(proj)
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
      return if @list.projects.include?(proj)

      proj.add_species_list(@list)
      flash_notice(:attached_to_project.
                      t(object: :species_list, project: proj.title))
      @any_changes = true
    end

    def remove_species_list_from_project(proj)
      return unless @list.projects.include?(proj)

      proj.remove_species_list(@list)
      flash_notice(:removed_from_project.
                      t(object: :species_list, project: proj.title))
      @any_changes = true
    end

    def attach_observations_to_project(proj)
      obs = @list.observations.select { |o| check_permission(o) }
      obs -= proj.observations
      return unless obs.any?

      proj.add_observations(obs)
      flash_notice(:attached_to_project.
                      t(object: "#{obs.length} #{:observations.l}",
                        project: proj.title))
      @any_changes = true
    end

    def remove_observations_from_project(proj)
      obs = @list.observations.select { |o| check_permission(o) }
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
      imgs = @list.observations.map(&:images).flatten.uniq.
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
      imgs = @list.observations.map(&:images).flatten.uniq.
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

    ############################################################################

    include SpeciesLists::SharedPrivateMethods # shared private methods
  end
end
