# frozen_string_literal: true

#  eol::
module Names
  class EolDataController < ApplicationController
    before_action :login_required

    ##########################################################################
    #
    #  :section: EOL Feed
    #
    ##########################################################################

    # Send stuff to eol.
    def show
      @max_secs = params[:max_secs] ? params[:max_secs].to_i : nil
      @timer_start = Time.current
      @data = ::EolData.new
      render_xml(layout: false)
    end
  end
end
