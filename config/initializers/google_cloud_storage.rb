require "google/cloud/storage"
require "json"

unless Rails.env.test?
  Google::Cloud::Storage.configure do |config|
    config.project_id  = "mo-image-archive"
    config.credentials = JSON.load(
      File.new(Rails.root.join("config", "credentials",
                               "mo-image-archive-service-account.json"))
    )
  end
end
