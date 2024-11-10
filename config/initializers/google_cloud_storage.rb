require "google/cloud/storage"

# TODO: store in secrets?
Google::Cloud::Storage.configure do |config|
  config.project_id  = ENV["GOOGLE_CLOUD_PROJECT"]
  config.credentials = ENV["GOOGLE_CLOUD_CREDENTIALS"]
end
