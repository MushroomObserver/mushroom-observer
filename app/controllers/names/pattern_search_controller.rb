# frozen_string_literal: true

# Names pattern search form.
#
# Route: `new_name_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/names/pattern_search", action: :create }`
module Names
  class PatternSearchController < ApplicationController
    before_action :login_required

    def new
      @fields = name_search_params
    end

    def create
      @pattern = human_formatted_pattern_search_string
      redirect_to(controller: "/names", action: :index, pattern: @pattern)
    end

    private

    def permitted_search_params
      params.permit(name_search_params)
    end

    def name_search_params
      PatternSearch::Name.params.keys
    end

    # Roundabout: We're converting the params hash back into a normal query
    # string to start with, and then we're translating the query string into the
    # format that the user would have typed into the search box if they knew how
    # to do that, because that's what the PatternSearch class expects to parse.
    # The PatternSearch class then unpacks, validates and re-translates all
    # these params into the actual params used by the Query class. This may seem
    # odd: of course we do know the Query param names in advance, so we could
    # theoretically just pass the values directly into Query and render the
    # index. But we'd still have to be able to validate the input, and give
    # messages for all the possible errors there. PatternSearch class handles
    # all that.
    def human_formatted_pattern_search_string
      query_string = permitted_search_params.compact_blank.to_query
      query_string.tr("=", ":").tr("&", " ").tr("%2C", "\\\\,")
    end
  end
end
