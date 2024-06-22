# frozen_string_literal: true

# Wrap API call that adds an Image from an url to an Observation
# Goal: allow stubbing the call's behavior and return value
class InatPhotoImporter
  def initialize(params)
    API2.execute(params)
  end
end
