# frozen_string_literal: true

# display information about user contributions to the site
class ContributorsController < ApplicationController
  before_action :login_required

  # Contributors index

  # Used by ApplicationController to dispatch #index to a private method
  @index_subaction_param_keys = [
    :by, :q, :id
  ].freeze

  @index_subaction_dispatch_table = {
    by: :index_query_results,
    q: :index_query_results,
    id: :index_query_results
  }.freeze

  ###########################################################

  private

  def default_index_subaction
    list_all
  end

  def default_sort_order
    :contribution
  end

  def list_all
    query = create_query(:User, :all, with_contribution: true,
                                      by: :contribution)
    show_selected(query)
  end

  # Show selected list, based on current Query.
  # (Linked from show template, next to "prev" and "next"... or will be.)
  def index_query_results
    sorted_by = params[:by].present? ? params[:by].to_s : default_sort_order
    query = find_or_create_query(:User, :all, with_contribution: true,
                                              by: sorted_by)
    at_id_args = { id: params[:id].to_s, always_index: true }
    show_selected(query, at_id_args)
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
