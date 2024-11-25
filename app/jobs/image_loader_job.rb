# frozen_string_literal: true

class ImageLoaderJob < ApplicationJob
  queue_as :default

  before_enqueue { write_status(:queued) }
  before_perform { write_status(:working) }
  after_perform  { write_status(:completed) }

  def perform(image_id, user_id)
    file = Image.cached_original_file_path(image_id)
    return if File.exist?(file) # already cached?

    load_image(image_id)
    update_quotas(user_id)
  rescue StandardError => e
    write_status(:failed)
    log(e.message)
    if Rails.env.test? && e.message != "test"
      warn("Caught error in ImageLoaderJob: #{e.message}\n" +
           e.backtrace.join("\n"))
    end
  end

  private

  def load_image(image_id)
    file = Image.cached_original_file_path(image_id)
    bucket = Google::Cloud::Storage.new.bucket(MO.image_bucket_name)
    blob = bucket.file("orig/#{image_id}.jpg")
    blob.download("#{file}.#{Process.pid}")
    FileUtils.move("#{file}.#{Process.pid}", file)
  end

  def update_quotas(user_id)
    User.find(user_id)&.increment!(:original_image_quota)
    User.admin.increment!(:original_image_quota)
  end

  def write_status(status)
    image_id = arguments.first
    file = Image.cached_original_file_path(image_id)
    FileUtils.mkdir_p(File.dirname(file))
    File.write("#{file}.status", status.to_s)
  end
end
