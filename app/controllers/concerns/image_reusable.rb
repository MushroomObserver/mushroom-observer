# frozen_string_literal: true

# Loads the paginated image set for the "reuse an image" pages, used
# by `Observations::ImagesController#reuse`,
# `Account::Profile::ImagesController#reuse`, and
# `GlossaryTerms::ImagesController#reuse`. Each of those `reuse`
# actions renders the same `Components::ImagesToReuseForm`, which
# receives the loaded data as props.
module ImageReusable
  extend ActiveSupport::Concern

  # Reads `params[:all_users]` to decide whether to query all users'
  # images or just the current user's. Sets:
  #   - @reuse_all_users    boolean
  #   - @reuse_layout       layout-params hash (count per page)
  #   - @reuse_pagination   pagination data (page / per_page)
  #   - @reuse_images       paginated Image collection
  def load_images_to_reuse
    @reuse_all_users = params[:all_users] == "1"
    query = query_images_to_reuse(@reuse_all_users, @user)
    @reuse_layout = calc_layout_params
    @reuse_pagination = number_pagination_data(:page, @reuse_layout["count"])
    @reuse_images = query.paginate(
      @reuse_pagination,
      include: [:user, { observations: :name }]
    )
  end
end
