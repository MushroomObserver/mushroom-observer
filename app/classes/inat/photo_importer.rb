# frozen_string_literal: true

# Wraps API call that adds an Image, based on its url, to an Observation
# This facilitates stubbing the call
class Inat
  class PhotoImporter
    attr_reader :api

    def initialize(params)
      @api = API2.execute(params)
    end
  end
end
