# frozen_string_literal: true

# see observations_controller.rb
class ObservationsController
  module Index
    def index
      make_name_suggestions
      build_index_with_query
    end

    def render_index_view
      render(Views::Controllers::Observations::Index.new(
               query: @query,
               pagination_data: @pagination_data,
               objects: @objects,
               user: @user,
               project: @project,

               name_suggestions: @name_suggestions
             ))
    end

    # `Components::Matrix::Table` bypasses the fragment cache when
    # rendering for a project admin (the admin-only Exclude button
    # changes the markup). When the obs index is scoped to a project
    # AND the current user is an admin of it, the controller's
    # cache pre-check must agree — otherwise it would skip eager-
    # loading rows it thinks are cache hits and then render uncached
    # boxes → N+1.
    def matrix_caches_in_this_request?
      !@project&.is_admin?(@user)
    end

    # Sort options for the index page. Read by `add_sorter` in the
    # view. Each key must resolve to `Observation.order_by_<key>`.
    # An unfiltered index (browsing the whole table) only offers
    # plain-column sorts with no join/aggregate -- name/user/
    # confidence/thumbnail_quality/num_views all cost a join or
    # aggregate over the full table otherwise.
    def index_sort_options
      if unfiltered_index_for_sort?
        unfiltered_index_sort_options
      else
        filtered_index_sort_options
      end
    end

    private

    # A bookmarked/permalinked unfiltered index can still carry an
    # `order_by` that isn't in the unfiltered allowlist (e.g.
    # `q[order_by]=name` with no other params) -- treat that as
    # filtered for the dropdown too, or `Sorter#toggle_title` can't
    # find a label for the current sort and the toggle goes blank.
    def unfiltered_index_for_sort?
      @query.params.except(:order_by).blank? && current_order_sort_safe?
    end

    def current_order_sort_safe?
      order = @query.params[:order_by].to_s.sub(/^reverse_/, "")
      order.blank? || unfiltered_index_sort_options.map(&:first).include?(order)
    end

    def unfiltered_index_sort_options
      [
        ["rss_log",    :sort_by_activity.l],
        ["date",       :sort_by_date.l],
        ["created_at", :sort_by_posted.l]
      ].freeze
    end

    def filtered_index_sort_options
      [
        ["rss_log",           :sort_by_activity.l],
        ["date",              :sort_by_date.l],
        ["created_at",        :sort_by_posted.l],
        ["name",              :sort_by_name.l],
        ["user",              :sort_by_user.l],
        ["confidence",        :sort_by_confidence.l],
        ["thumbnail_quality", :sort_by_thumbnail_quality.l],
        ["num_views",         :sort_by_num_views.l]
      ].freeze
    end

    # Default on home is :rss_log (:log_updated_at), not :date.
    # Maybe other filters should explicitly specify :date?
    # Then we could use default_sort_order above.
    # Or, set an "unfiltered sort order" method that defaults to this.
    def default_sort_order
      ::Query::Observations.default_order # :date
    end

    # Note all other filters of the obs index are sorted by date.
    def unfiltered_index_opts
      super.merge(query_args: { order_by: :rss_log })
    end

    # Different from NamesController. Returns arrays of [name, count]
    def make_name_suggestions
      return unless @objects.empty? &&
                    params[:q].is_a?(ActionController::Parameters) &&
                    (original_spelling = params.dig(:q, :pattern))

      names = Name.suggest_alternate_spellings(original_spelling)
      @name_suggestions = names.sort_by(&:sort_name).map do |name|
        query = Query.create_query(:Observation, pattern: name.text_name)
        count = query.num_results
        [name, count]
      end
    end

    # Hook runs before template displayed. Must return query.
    def filtered_index_final_hook(query, _display_opts)
      store_query_in_session(query)
      derive_ivar_from_query(:@project, query, :projects, Project)
      query
    end

    def index_display_opts(opts, query)
      # We always want cached matrix boxes for observations if possible.
      # cache: true  will batch load the includes only for fragments not cached.
      opts = {
        matrix: true, cache: true,
        include: observation_index_includes
      }.merge(opts)

      # Offer pagination by letter only if the index has been filtered
      # and we're sorting by user or name.
      if query.params.except(:order_by).present? &&
         %w[user reverse_user name reverse_name].include?(
           query.params[:order_by]
         )
        opts[:letters] = true
      end

      opts
    end

    # Reuses `Observation.matrix_box_includes` — the canonical tree
    # shared by every matrix-box render (field_slips show/index,
    # collection_numbers show).
    def observation_index_includes
      Observation.matrix_box_includes
    end
  end
end
