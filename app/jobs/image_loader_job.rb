# frozen_string_literal: true

class ImageLoaderJob < ApplicationJob
  queue_as :default

  before_enqueue { write_status(:queued) }
  before_perform { write_status(:working) }
  after_perform  { write_status(:completed) }

  rescue_from(Exception) do |e|
    write_status(:failed)
    raise e
  end

  def perform(image_id, user_id)
    image = Image.find(image_id)
    return if image.id >= MO.next_image_id_to_go_to_cloud   # on image server?
    return if File.exist?(image.cached_original_file_path)  # already cached?

    load_image(image)
    update_quotas(user_id)
  end

  private

  def load_image(image)
    file = image.cached_original_file_path
    bucket = Google::Cloud::Storage.new.bucket(MO.image_bucket_name)
    blob = bucket.file("orig/#{image.id}.jpg")
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
