# frozen_string_literal: true

#  == EOL
#  eol_preview::
#  eol_data::
#  eol_expanded_review::
#  eol::

module Names
  class EolDataController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    ##########################################################################
    #
    #  :section: EOL Feed
    #
    ##########################################################################

    # Send stuff to eol.
    def eol
      @max_secs = params[:max_secs] ? params[:max_secs].to_i : nil
      @timer_start = Time.current
      @data = EolData.new
      render_xml(layout: false)
    end
  end
end
