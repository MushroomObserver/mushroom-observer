# frozen_string_literal: true

# Wraps API call that adds an Image an Observation from the Image url
# This facilitates stubbing the call
class InatPhotoImporter
  attr_reader :api

  def initialize(params)
    @api = API2.execute(params)
  end
end