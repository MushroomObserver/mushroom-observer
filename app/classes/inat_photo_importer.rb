# frozen_string_literal: true

# Wrap API call that adds an Image an Observation from the Image url
# Enables stubbing the API call's return value (but not its behavior)
class InatPhotoImporter
  attr_reader :api

  def initialize(params)
    @api = API2.execute(params)
  end
end
