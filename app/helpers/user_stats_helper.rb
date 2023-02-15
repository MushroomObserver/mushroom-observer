# frozen_string_literal: true

# Helpers for user view
module UserStatsHelper
  def user_stats_links(user)
    links = {}
    user_stats_links_table(user).each do |key, controller, action, params|
      unless [key].intersect?([:location_description_authors,
                               :name_description_authors])
        params[:id] = user.id
      end

      links[key] = url_for(controller: controller, action: action,
                           params: params)
    end
    links
  end

  #########################################################

  private

  # NOTE: Second arg is controller name
  # Last arg is a hash of index params.
  def user_stats_links_table(user)
    [
      [:comments, "/comments", :index, { by_user: user.id }],
      [:comments_for, "/comments", :index, { for_user: user.id }],
      [:images, "/images", :index, { by_user: user.id }],
      [:location_description_authors, "/locations/descriptions",
       :index, { by_author: user.id }],
      [:location_description_editors, "/locations/descriptions",
       :index, { by_editor: user.id }],
      [:locations, "/locations", :index, { by_user: user.id }],
      [:locations_versions, "/locations", :index, { by_editor: user.id }],
      [:name_description_authors, "/names/descriptions",
       :index, { by_author: user.id }],
      [:name_description_editors, "/names/descriptions",
       :index, { by_editor: user.id }],
      [:names, "/names", :index, { by_user: user.id }],
      [:names_versions, "/names", :index, { by_editor: user.id }],
      [:observations, "/observations", :index, { user: user.id }],
      [:species_lists, "/species_lists", :index, { by_user: user.id }],
      [:life_list, "/checklists", :show, {}]
    ]
  end
end
