# frozen_string_literal: true

#  == EOL
#  eol_preview::
#  eol_data::
#  eol_expanded_review::
#  eol::

module Names::EolData
  class ExpandedReviewController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    def eol_expanded_review
      @timer_start = Time.current
      @data = EolData.new
    end
        # TODO: Add ability to preview synonyms?
    # TODO: List stuff that's almost ready.
    # TODO: Add EOL logo on pages getting exported
    #   show_name and show_descriptions for description info
    #   show_name, observations/show and show_image for images
    # EOL preview from Name page
    # Improve the Name page
    # Review unapproved descriptions


  end
end
