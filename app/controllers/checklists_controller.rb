# frozen_string_literal: true

class ChecklistsController < ApplicationController
  # filters
  before_action :login_required
  before_action :pass_query_params

  # Old MO Action (method)        New "Normalized" Action (method)
  # ----------------------------  --------------------------------
  # observer_checklist (get)      Checklists (get)

  # Display a checklist of species seen by a User, Project,
  # SpeciesList or the entire site.
  def show
    store_location
    user_id = params[:user_id] || params[:id]
    proj_id = params[:project_id]
    list_id = params[:species_list_id]

    @data = if user_id.present?
              user_checklist(user_id)
            elsif proj_id.present?
              project_checklist(proj_id)
            elsif list_id.present?
              species_list_checklist(list_id)
            else
              Checklist::ForSite.new
            end
  end

  ##############################################################################

  private

  def user_checklist(user_id)
    return unless (@show_user = find_or_goto_index(User, user_id))
    Checklist::ForUser.new(@show_user)
  end

  def project_checklist(proj_id)
    return unless (@project = find_or_goto_index(Project, proj_id))
    Checklist::ForProject.new(@project)
  end

  def species_list_checklist(list_id)
    return unless (@species_list = find_or_goto_index(SpeciesList, list_id))
    Checklist::ForSpeciesList.new(@species_list)
  end
end
