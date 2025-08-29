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

  private

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
    super.merge(query_args: { has_contribution: true })
  end

  def index_display_opts(opts, _query)
    { matrix: true,
      letters: true,
      include: [:image, :location] }.merge(opts)
  end
end
