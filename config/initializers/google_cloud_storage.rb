# frozen_string_literal: true

require "google/cloud/storage"
require "json"

file = File.new(Rails.root.join("config/credentials",
                                "mo-image-archive-service-account.json"))
# For some reason the autotester on github will still try to load this file
# even though it should presumably be in test mode.
if File.exist? && !Rails.env.test?
  Google::Cloud::Storage.configure do |config|
    config.project_id  = "mo-image-archive"
    config.credentials = JSON.parse(file)
  end
end
