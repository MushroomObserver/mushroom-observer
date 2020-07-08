# frozen_string_literal: true

# TODO: move this into a new InfoController
# Display canned informations about site
class ObserverController
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
  def translators_note
  end
end
