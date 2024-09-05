# frozen_string_literal: true

#
#  = PatternSearchable Concern
#
#  This is a module of reusable methods that can be included by controllers that
#
################################################################################

module PatternSearchable
  extend ActiveSupport::Concern

  included do

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
