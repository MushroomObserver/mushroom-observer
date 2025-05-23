# frozen_string_literal: true

# see field_slips_controller.rb
module FieldSlipsController::Index
  def index
    build_index_with_query
  end

  private

  def default_sort_order
    ::Query::FieldSlips.default_order # :date
  end

  def index_active_params
    [:project, :by_user, :by, :q, :id].freeze
  end

  # Display list of FieldSlips attached to a given project.
  def project
    return unless (
      project = find_or_goto_index(Project, params[:project].to_s)
    )

    query = create_query(:FieldSlip, projects: project)
    @project = project
    [query, { always_index: true }]
  end

  # Displays list of User's FieldSlips, by date.
  def by_user
    return unless (user = find_or_goto_index(User, params[:by_user]))

    query = create_query(:FieldSlip, by_users: user)
    [query, {}]
  end

  def index_display_opts(opts, _query)
    { num_per_page: 50,
      include: field_slip_includes }.merge(opts)
  end

  # Used on index, but could be used on show, edit? update? as well.
  def field_slip_includes
    [{ observation: [:location, :name, :namings, :rss_log, :user] },
     :project, :user]
  end
end
