# frozen_string_literal: true

# Display canned informations about site
class InfoController < ApplicationController
  before_action :login_required, except: [
    :how_to_help,
    :how_to_use,
    :intro
  ]
  before_action :store_location,
                except: [:textile_sandbox, :textile_sandbox_create,
                         :translators_note]

  # Intro to site.
  def intro
    render(Views::Controllers::Info::Intro.new)
  end

  # Recent features.
  def news
    render(Views::Controllers::Info::News.new)
  end

  # Help page.
  def how_to_use
    @min_pos_vote = Vote.confidence(Vote.min_pos_vote)
    @min_neg_vote = Vote.confidence(Vote.min_neg_vote)
    @maximum_vote = Vote.confidence(Vote.maximum_vote)
    render(Views::Controllers::Info::HowToUse.new(
             min_pos_vote: @min_pos_vote,
             min_neg_vote: @min_neg_vote,
             maximum_vote: @maximum_vote
           ))
  end

  # A few ways in which users can help.
  def how_to_help
    render(Views::Controllers::Info::HowToHelp.new)
  end

  # linked from search bar
  def search_bar_help
    render(Views::Controllers::Info::SearchBarHelp.new)
  end

  # GET /info/textile_sandbox/new — empty form
  def textile_sandbox
    render(Views::Controllers::Info::TextileSandbox.new(
             textile_sandbox: FormObject::TextileSandbox.new(code: nil),
             show_result: false,
             submit_type: nil
           ))
  end

  # POST /info/textile_sandbox — render result
  def textile_sandbox_create
    code = params[:code] || params.dig(:textile_sandbox, :code)
    render(Views::Controllers::Info::TextileSandbox.new(
             textile_sandbox: FormObject::TextileSandbox.new(code: code),
             show_result: !code.nil?,
             submit_type: params[:commit]
           ))
  end

  # Allow translator to enter a special note linked to from the lower left.
  def translators_note
    render(Views::Controllers::Info::TranslatorsNote.new(
             languages: Language.all.sort_by(&:order)
           ))
  end

  def site_stats
    @site_data = SiteData.new.get_site_data

    # Get the last six observations whose thumbnails are highly rated.
    # This is a pricey query any way you cut it. Limiting recency speeds it up.
    @observations = Observation.updated_at(4.months.ago.strftime("%Y-%m-%d")).
                    joins(:thumb_image).merge(Image.quality(3)).
                    includes(thumb_image: :image_votes).
                    order(updated_at: :desc).limit(6).to_a
    render(Views::Controllers::Info::SiteStats.new(
             site_data: @site_data, observations: @observations.to_a
           ))
  end
end
