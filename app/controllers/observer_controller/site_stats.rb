# frozen_string_literal: true

# see observer_controller.rb
class ObserverController
  def show_site_stats
    store_location
    @site_data = SiteData.new.get_site_data

    # Add some extra stats.
    @site_data[:observed_taxa] = Name.connection.select_value(%(
      SELECT COUNT(DISTINCT name_id) FROM observations
    ))
    @site_data[:listed_taxa] = Name.connection.select_value(%(
      SELECT COUNT(*) FROM names
    ))

    # Get the last six observations whose thumbnails are highly rated.
    query = Query.lookup(:Observation, :all,
                         by: :updated_at,
                         where: "images.vote_cache >= 3",
                         join: :"images.thumb_image")
    @observations = query.results(limit: 6,
                                  include: { thumb_image: :image_votes })
  end
end
