# frozen_string_literal: true

class ChecklistsController < ApplicationController
  # filters
  before_action :login_required, unless: :public_checklist_request?
  before_action :store_location

  # Exact query-param sets a logged-out visitor may request. Anything
  # else (site-wide, user, location, `q`, extra params) needs a login,
  # so crawlers cannot multiply URL variants of the public pages.
  PUBLIC_PARAM_SETS = [
    %w[project_id],
    %w[species_list_id],
    %w[project species_list_id]
  ].freeze

  # Old MO Action (method)        New "Normalized" Action (method)
  # ----------------------------  --------------------------------
  # observer_checklist (get)      Checklists (get)

  # Display a checklist of species seen by a User, Project,
  # SpeciesList or the entire site.
  def show
    user_id = params[:user_id] || params[:id]
    proj_id = params[:project_id]
    list_id = params[:species_list_id]
    # Picks up a `project` param (or single-project query) so a
    # checklist reached from a project-scoped page keeps the project
    # banner -- same context passing as SpeciesListsController#show.
    set_project_ivar

    @data = if user_id.present?
              user_checklist(user_id)
            elsif proj_id.present?
              project_checklist(proj_id, params[:location_id])
            elsif list_id.present?
              species_list_checklist(list_id)
            else
              Checklist::ForSite.new
            end
    return unless @data

    response.set_header("X-Robots-Tag", "noindex")
    render(Views::Controllers::Checklists::Show.new(
             data: @data, context: checklist_context,
             project_data: @project_checklist
           ))
  end

  ##############################################################################

  private

  def public_checklist_request?
    query = request.query_parameters
    PUBLIC_PARAM_SETS.include?(query.keys.sort) &&
      query.values.all? { |value| value.to_s.match?(/\A\d+\z/) }
  end

  def checklist_context
    Views::Controllers::Checklists::Context.new(
      user: @user, project: @project, show_user: @show_user,
      location: @location, species_list: @species_list,
      logged_out: @user.nil?
    )
  end

  def user_checklist(user_id)
    return unless (@show_user = find_or_goto_index(User, user_id))

    Checklist::ForUser.new(@show_user)
  end

  def project_checklist(proj_id, location_id)
    return unless (@project = find_or_goto_index(Project, proj_id))

    @location = Location.safe_find(location_id)
    sub = params[:sub_locations] == "1"

    Checklist::ForProject.new(@project, @location,
                              include_sub_locations: sub)
  end

  def species_list_checklist(list_id)
    return unless (@species_list = find_or_goto_index(SpeciesList, list_id))

    # Feeds the "Missing Taxa" panel (project taxa absent from the list)
    # when the checklist carries project context.
    @project_checklist = Checklist::ForProject.new(@project) if @project
    Checklist::ForSpeciesList.new(@species_list)
  end
end
