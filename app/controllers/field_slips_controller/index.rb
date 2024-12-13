# frozen_string_literal: true

# see field_slips_controller.rb
module FieldSlipsController::Index
  def index
    build_index_with_query
  end

  private

  def default_sort_order
    :date
  end

  def index_active_params
    [:project, :by_user, :by, :q, :id].freeze
  end

  # Display list of FieldSlips attached to a given project.
  def project
    return unless (
      project = find_or_goto_index(Project, params[:project].to_s)
    )

    query = create_query(:FieldSlip, :all, project: project)
    filtered_index(query, always_index: true)
  end

  # Displays list of User's FieldSlips, by date.
  def by_user
    return unless (user = find_or_goto_index(User, params[:by_user]))

    query = create_query(:FieldSlip, :all, by_user: user)
    filtered_index(query)
  end

  def index_display_args(args, _query)
    {
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
