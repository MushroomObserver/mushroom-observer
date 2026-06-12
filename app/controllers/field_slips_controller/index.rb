# frozen_string_literal: true

# see field_slips_controller.rb
module FieldSlipsController::Index
  def index
    build_index_with_query
  end

  # Overrides `ApplicationController::Indexes#render_index_view` so
  # `show_index_of_objects` renders the Phlex `Index` class instead
  # of `field_slips/index.html.erb` (deleted).
  def render_index_view
    render(Views::Controllers::FieldSlips::Index.new(
             objects: @objects, query: @query, project: @project,
             pagination_data: @pagination_data,
             notice: flash[:notice]
           ))
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

  # `show_index_of_objects` consumes `:include` as an array of
  # association names (with nested hashes for deeper associations).
  # Pull it from `FieldSlip.index_includes_tree` so the same shape
  # used by the `index_includes` scope is the one applied here.
  def index_display_opts(opts, _query)
    { num_per_page: 50,
      include: FieldSlip.index_includes_tree }.merge(opts)
  end
end
