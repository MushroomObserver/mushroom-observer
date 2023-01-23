# frozen_string_literal: true

# list_merge_options
module Locations
  class MergesController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    ############################################################################
    #
    #  :section: Merging Locations
    #
    ############################################################################

    # Show a list of defined locations that match a given +where+ string, in
    # order of closeness of match.
    def new
      store_location
      @where = Location.user_name(@user, params[:where].to_s)
      @matches = Location.name_includes(@where)
      @where.split(",").each do |part|
        @matches = @matches.or(Location.name_includes(part))
      end
    end
  end
end
