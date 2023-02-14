# frozen_string_literal: true

# View Helpers for GlossaryTerms
module UserStatsHelper
  def user_stats_links(show_user)
    # NOTE: Second arg is controller name - plural for normalized.
    # Normalized controller links last arg must be hash of index params.
    links = {}
    [
      [:comments, "/comments", :index, { by_user: show_user.id }],
      [:comments_for, "/comments", :index, { for_user: show_user.id }],
      [:images, "/images", :index, { by_user: show_user.id }],
      [:location_description_authors, "/locations/descriptions",
       :index, { by_author: show_user.id }],
      [:location_description_editors, "/locations/descriptions",
       :index, { by_editor: show_user.id }],
      [:locations, "/locations", :index, { by_user: show_user.id }],
      [:locations_versions, "/locations", :index, { by_editor: show_user.id }],
      [:name_description_authors, "/names/descriptions",
       :index, { by_author: show_user.id }],
      [:name_description_editors, "/names/descriptions",
       :index, { by_editor: show_user.id }],
      [:names, "/names", :index, { by_user: show_user.id }],
      [:names_versions, "/names", :index, { by_editor: show_user.id }],
      [:observations, "/observations", :index, { user: show_user.id }],
      [:species_lists, "/species_lists", :index, { by_user: show_user.id }],
      [:life_list, "/checklists", :show, {}]
    ].each do |key, controller, action, params|
      unless [key].intersect?([:location_description_authors,
                               :name_description_authors])
        params[:id] = show_user.id
      end

      links[key] = url_for(controller: controller, action: action,
                           params: params)
    end
    links
  end
end
