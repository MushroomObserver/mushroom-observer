# frozen_string_literal: true

# see field_slips_controller.rb
module FieldSlipsController::Index
  private

  # index subactions:
  # methods called by #index via the dispatch table in FieldSlipsController

  # checked by ApplicationController#index
  def default_index_subaction
    list_all
  end

  def list_all
    query = create_query(:FieldSlip, :all, by: :created_at)
    show_selected_field_slips(query)
  end

  # Displays matrix of selected FieldSlips (based on current Query).
  def index_query_results
    query = find_or_create_query(:FieldSlip, by: params[:by])
    show_selected_field_slips(
      query, id: params[:id].to_s, always_index: true
    )
  end

  # Display FieldSlip attached to a given observation.
  def observation
    return unless (
      observation = find_or_goto_index(Observation, params[:observation].to_s)
    )

    query = create_query(:FieldSlip, :all, observation: observation)
    show_selected_field_slips(query, always_index: 1)
  end

  # Display list of FieldSlips attached to a given project.
  def project
    return unless (
      project = find_or_goto_index(Project, params[:project].to_s)
    )

    query = create_query(:FieldSlip, :all, project: project)
    show_selected_field_slips(query, always_index: 1)
  end

  # Displays list of User's FieldSlips, by date.
  def user
    return unless (
      user = find_or_goto_index(User, params[:user])
    )

    query = create_query(:FieldSlip, :all, by_user: user)
    show_selected_field_slips(query)
  end

  # Show selected list of field_slips.
  def show_selected_field_slips(query, args = {})
    args = {
      action: :index,
      num_per_page: 50,
      include: field_slip_includes
    }.merge(args)

    show_index_of_objects(query, args)
  end

  # Used on index, but could be used on show, edit? update? as well.
  def field_slip_includes
    [{ observation: [:location, :name, :namings, :rss_log, :user] },
     :project, :user]
  end
end
