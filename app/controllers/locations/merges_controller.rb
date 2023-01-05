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
    def list_merge_options
      store_location
      @where = Location.user_name(@user, params[:where].to_s)

      # Split list of all locations into "matches" and "non-matches".  Try
      # matches in the following order:
      #   1) all that start with full "where" string
      #   2) all that start with everything in "where" up to the comma
      #   3) all that start with the first word in "where"
      #   4) there just aren't any matches, give up
      all = Location.all.order("name")
      @matches, @others = (
        split_out_matches(all, @where) ||
        split_out_matches(all, @where.split(",").first) ||
        split_out_matches(all, @where.split.first) ||
        [nil, all]
      )
    end

    private

    # Split up +list+ into those that start with +substring+ and those that
    # don't.  If none match, then return nil.
    def split_out_matches(list, substring)
      matches = list.select do |loc|
        (loc.name.to_s[0, substring.length] == substring)
      end
      if matches.empty?
        nil
      else
        [matches, list - matches]
      end
    end
  end
end
