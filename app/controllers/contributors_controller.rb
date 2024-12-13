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

  private

  def controller_model_name
    "User"
  end

  def default_sort_order
    :contribution
  end

  def unfiltered_index_opts
    super.merge(query_args: { with_contribution: true })
  end

  # Show selected list, based on current Query.
  # Passes explicit :by param to affect title (only).
  # (Linked from show template, next to "prev" and "next"... or will be.)
  def sorted_index_opts
    sorted_by = params[:by] || default_sort_order
    super.merge(query_args: { with_contribution: true, by: sorted_by })
  end

  def index_display_opts(opts, _query)
    {
      matrix: true,
      include: [:image]
    }.merge(opts)
  end
end
