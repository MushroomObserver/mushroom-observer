# frozen_string_literal: true

# Query/pagination support for InatImportsController#index.
module InatImportsController::IndexQuery
  # Sort options for the iNat imports index. Read by `add_sorter`
  # in the view. The `user` sort option only makes sense in Admin Mode --
  # a non-admin's rows share one user, and the User column itself only
  # renders there too.
  def index_sort_options(admin:)
    options = [
      ["updated_at", :sort_by_updated_at.t],
      ["created_at", :sort_by_created_at.t]
    ]
    options << ["user", :sort_by_user.t] if admin
    options.freeze
  end

  private

  # Forces every non-admin request onto the generic index pipeline's
  # filtered-index dispatch (`other_filter_param_present?`), scoped to
  # the signed-in user. An overwrite, not `||=`: a non-admin's request
  # can't supply a different `by_user` param to see another user's
  # imports.
  def force_own_imports_only_param
    params[:by_user] = @user.id
  end

  # `opts` wins where it sets something unique; `always_index: true`
  # must win regardless, since the hand-rolled index this replaces
  # didn't redirect a single-result list to its show page.
  def index_display_opts(opts, _query)
    opts.merge(num_per_page: calc_layout_params["count"],
               always_index: true)
  end

  def render_index_view
    render(Views::Controllers::InatImports::Index.new(
             query: @query, pagination_data: @pagination_data,
             objects: @objects, admin: in_admin_mode? == true,
             result_import_ids: import_ids_with_results(@objects)
           ))
  end

  # Ids of the imports with linked observations. Historic imports predate
  # the observations.inat_import_id link, so their Results link would lead
  # nowhere; the index hides it for them. One query per page, to avoid an
  # N+1 across the current page's imports.
  def import_ids_with_results(imports)
    Observation.where(inat_import_id: imports.map(&:id)).
      distinct.pluck(:inat_import_id)
  end
end
