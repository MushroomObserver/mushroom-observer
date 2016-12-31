# encoding: utf-8
# see observer_controller.rb
class ObserverController
  def show_site_stats # :nologin: :norobots:
    store_location
    @site_data = SiteData.new.get_site_data

    # Add some extra stats.
    @site_data[:observed_taxa] = Name.connection.select_value %(
      SELECT COUNT(DISTINCT name_id) FROM observations
    )
    @site_data[:listed_taxa] = Name.connection.select_value %(
      SELECT COUNT(*) FROM names
    )

    # Get the last six observations whose thumbnails are highly rated.
    query = Query.lookup(:Observation, :all,
                         by: :updated_at,
                         where: "images.vote_cache >= 3",
                         join: :"images.thumb_image")
    @observations = query.results(limit: 6,
                                  include: { thumb_image: :image_votes })
  end

  # Reports on the health of the system
  def server_status # :root: :norobots:
    if is_in_admin_mode?
      case params[:commit]
      when :system_status_gc.l
        ObjectSpace.garbage_collect
        flash_notice("Collected garbage")
      when :system_status_clear_caches.l
        String.clear_textile_cache
        flash_notice("Cleared caches")
      end
      @textile_name_size = String.textile_name_size
    else
      redirect_to(action: "list_observations")
    end
  end
end
