# frozen_string_literal: true

class ChecklistsController < ApplicationController
  # filters
  before_action :login_required
  before_action :pass_query_params
  before_action :keep_track_of_referrer

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
    if user_id.present?
      if (@show_user = find_or_goto_index(User, user_id))
        @data = Checklist::ForUser.new(@show_user)
      end
    elsif proj_id.present?
      if (@project = find_or_goto_index(Project, proj_id))
        @data = Checklist::ForProject.new(@project)
      end
    elsif list_id.present?
      if (@species_list = find_or_goto_index(SpeciesList, list_id))
        @data = Checklist::ForSpeciesList.new(@species_list)
      end
    else
      @data = Checklist::ForSite.new
    end
  end
end
