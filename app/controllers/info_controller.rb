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
    if request.method != "POST"
      @code = nil
    else
      @code = params[:code]
      @submit = params[:commit]
    end
    render(action: :textile_sandbox)
  end

  # I keep forgetting the stupid "_sandbox" thing.
  alias textile textile_sandbox

  # Allow translator to enter a special note linked to from the lower left.
  def translators_note; end

  def site_stats
    store_location
    @site_data = SiteData.new.get_site_data

    # Add some extra stats.
    @site_data[:observed_taxa] = Observation.distinct.count(:name_id)
    @site_data[:listed_taxa] = Name.count

    # Get the last six observations whose thumbnails are highly rated.
    query = Query.lookup(:Observation, :all,
                         by: :updated_at,
                         where: "images.vote_cache >= 3",
                         join: :"images.thumb_image")
    @observations = query.results(limit: 6,
                                  include: { thumb_image: :image_votes })
  end

  # Simple list of all the files in public/html that are linked to the W3C
  # validator to make testing easy.
  def w3c_tests
    render(layout: false)
  end

  # Update banner across all translations.
  def change_banner
    if !in_admin_mode?
      flash_error(:permission_denied.t)
      redirect_to("/")
    elsif request.method == "POST"
      @val = params[:val].to_s.strip
      @val = "X" if @val.blank?
      time = Time.zone.now
      Language.all.each do |lang|
        if (str = lang.translation_strings.where(tag: "app_banner_box")[0])
          str.update!(
            text: @val,
            updated_at: (str.language.official ? time : time - 1.minute)
          )
        else
          str = lang.translation_strings.create!(
            tag: "app_banner_box",
            text: @val,
            updated_at: time - 1.minute
          )
        end
        str.update_localization
        str.language.update_localization_file
        str.language.update_export_file
      end
      redirect_to("/")
    else
      @val = :app_banner_box.l.to_s
    end
  end
end
