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
    query = create_query(:FieldSlip, :all)
    show_selected(query)
  end

  # Displays index at the page containing the last field slip viewed.
  # (can be used by the "Back" button on the show page.)
  def index_query_results
    query = find_or_create_query(:FieldSlip, by: params[:by])
    at_id_args = { id: params[:id].to_s, always_index: true }
    show_selected(query, at_id_args)
  end

  # Display list of FieldSlips attached to a given project.
  def project
    return unless (
      project = find_or_goto_index(Project, params[:project].to_s)
    )

    query = create_query(:FieldSlip, :all, project: project)
    show_selected(query, always_index: true)
  end

  # Displays list of User's FieldSlips, by date.
  def by_user
    return unless (user = find_or_goto_index(User, params[:user]))

    query = create_query(:FieldSlip, :all, by_user: user)
    show_selected(query)
  end

  # Show selected list of field_slips.
  def show_selected(query, args = {})
    show_index_of_objects(query, index_display_args(args, query))
  end

  def index_display_args(args, _query)
    {
      action: :index,
      num_per_page: 50,
      include: field_slip_includes
    }.merge(args)
  end

  # Used on index, but could be used on show, edit? update? as well.
  def field_slip_includes
    [{ observation: [:location, :name, :namings, :rss_log, :user] },
     :project, :user]
  end
end