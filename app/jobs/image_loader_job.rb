# frozen_string_literal: true

class ImageLoaderJob < ApplicationJob
  queue_as :default

  def perform(image_id)
    image = Image.find(image_id)
    file = image.cached_original_file_path
    return if image.id >= MO.next_image_id_to_go_to_cloud  # on image server?
    return if File.exist?(file)                            # already cached?

    bucket = Google::Cloud::Storage.new.bucket(MO.image_bucket_name)
    blob = bucket.file("orig/#{image.id}.jpg")
    FileUtils.mkdir_p(File.dirname(file))
    blob.download("#{file}.#{Process.pid}")
    FileUtils.move("#{file}.#{Process.pid}", file)
  end
end
