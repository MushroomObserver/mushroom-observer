# frozen_string_literal: true

# display information about user contributions to the site
class ContributorsController < ApplicationController
  before_action :login_required

  ##############################################################################
  # INDEX
  #
  def index
    build_index_with_query
  end

  def controller_model_name
    "User"
  end

  # Sort options for the index page. Same shape as
  # `UsersController#index_sort_options` non-admin variant —
  # contributors page never offers the admin-only keys. Read by
  # `add_sorter` in the view.
  def index_sort_options
    [
      ["login",        :sort_by_login.t],
      ["name",         :sort_by_name.t],
      ["created_at",   :sort_by_created_at.t],
      ["location",     :sort_by_location.t],
      ["contribution", :sort_by_contribution.t]
    ].freeze
  end

  private

  # Phlex action template — no ERB resolver in phlex-rails 2.x, so the
  # render is explicit. See `.claude/rules/phlex_conversions.md`.
  def render_index_view
    render(Views::Controllers::Contributors::Index.new(
             query: @query, pagination_data: @pagination_data,
             objects: @objects
           ))
  end

  def default_sort_order
    :contribution # ::Query::Users.default_order is :name
  end

  def unfiltered_index_opts
    super.merge(query_args: { has_contribution: true })
  end

  # Show selected list, based on current Query.
  # Passes explicit :by param to affect title (only).
  # (Linked from show template, next to "prev" and "next"... or will be.)
  def sorted_index_opts
    super.deep_merge(query_args: { has_contribution: true })
  end

  def index_display_opts(opts, _query)
    { matrix: true,
      letters: true,
      include: [:image, :location] }.merge(opts)
  end
end
