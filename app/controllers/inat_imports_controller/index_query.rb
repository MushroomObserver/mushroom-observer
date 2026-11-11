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

  # Non-admins see only the imports they made; admins see everyone's,
  # unfiltered. `by_users: nil` is skipped by Query (same as omitting
  # the key), so this needn't branch into two separate `find_or_create_query`
  # calls.
  def index_query_args(admin)
    {
      by_users: (admin ? nil : [@user]),
      order_by: order_by_or_flash_if_unknown
    }
  end

  def index_pagination_data
    PaginationData.new(
      number_arg: :page,
      number: params[:page],
      num_per_page: calc_layout_params["count"]
    )
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
