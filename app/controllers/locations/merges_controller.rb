# frozen_string_literal: true

# list_merge_options
module Locations
  class MergesController < ApplicationController
    before_action :login_required

    ############################################################################
    #
    #  :section: Merging Locations
    #
    ############################################################################

    # Show a list of defined locations that match a given +where+ string, in
    # order of closeness of match, in the following order:
    #   1) matches = match the string
    #   1) others that start with everything in "where" up to the comma
    #   2) others that start with the first word in "where"
    #   3) doesn't try other segments, because the second one could be a country

    def new
      store_location
      @where = Location.user_format(@user, params[:where].to_s)
      @matches = Location.name_includes(@where)
      @others = []

      # Try for segments: split by comma, or by space if no commas
      places = @where.split(",")
      words = @where.split
      return unless places.length > 1 || words.length > 1

      @others = Location.name_includes(places.first).
                or(Location.name_includes(words.first))
    end
  end
end
