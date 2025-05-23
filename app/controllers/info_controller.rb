# frozen_string_literal: true

# Display canned informations about site
class InfoController < ApplicationController
  before_action :login_required, except: [
    :how_to_help,
    :how_to_use,
    :intro
  ]

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

  # Simple form letting us test our implementation of Textile.
  def textile_sandbox
    if request.method == "POST"
      @code = params[:code]
      @submit = params[:commit]
    else
      @code = nil
    end
    render(action: :textile_sandbox)
  end

  # Allow translator to enter a special note linked to from the lower left.
  def translators_note; end

  def site_stats
    store_location
    @site_data = SiteData.new.get_site_data

    # Get the last six observations whose thumbnails are highly rated.
    # This is a pricey query any way you cut it. Limiting recency speeds it up.
    @observations = Observation.updated_at(4.months.ago.strftime("%Y-%m-%d")).
                    joins(:thumb_image).merge(Image.quality(3)).
                    includes(thumb_image: :image_votes).
                    order(updated_at: :desc).limit(6)
  end
end
