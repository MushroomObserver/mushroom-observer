# Display canned informations about site
class InfoController < ApplicationController

  before_action :disable_link_prefetching

  # Intro to site.
  def intro
    store_location
  end

  # Recent features.
  def news
    store_location
  end

  # Help page.
  def how_to_use
    store_location
    @min_pos_vote = Vote.confidence(Vote.min_pos_vote)
    @min_neg_vote = Vote.confidence(Vote.min_neg_vote)
    @maximum_vote = Vote.confidence(Vote.maximum_vote)
  end

  # A few ways in which users can help.
  def how_to_help
    store_location
  end

  def wrapup_2011
    store_location
  end

  # linked from search bar
  def search_bar_help
    store_location
  end

  # Removed from observer
  def show_site_stats # :norobots:
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

  # Simple form letting us test our implementation of Textile.
  def textile_sandbox
    if request.method != "POST"
      @code = nil
    else
      @code = params[:code]
      @submit = params[:commit]
    end
    render(action: :textile_sandbox)
  end

  # I keep forgetting the stupid "_sandbox" thing.
  alias_method :textile, :textile_sandbox

  # Allow translator to enter a special note linked to from the lower left.
  def translators_note
  end
end
