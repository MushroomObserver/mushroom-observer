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

  def unfiltered_index
    query = create_query(:User, :all, with_contribution: true,
                                      by: default_sort_order)
    show_selected(query)
  end

  def default_sort_order
    :contribution
  end

  # Used by ApplicationController to dispatch #index to a private method
  def index_subaction_param_keys
    [:by, :q, :id].freeze
  end

  # Show selected list, based on current Query.
  # (Linked from show template, next to "prev" and "next"... or will be.)
  def index_query_results
    sorted_by = params[:by].present? ? params[:by].to_s : default_sort_order
    query = find_or_create_query(:User, with_contribution: true, by: sorted_by)
    show_selected(query, index_at_id_args)
  end

  def show_selected(query, args = {})
    show_index_of_objects(query, index_display_args(args, query))
  end

  def index_display_args(args, _query)
    {
      action: :index,
      matrix: true,
      include: [:image]
    }.merge(args)
  end
end
