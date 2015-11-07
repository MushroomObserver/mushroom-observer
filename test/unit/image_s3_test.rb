# encoding: utf-8
require "test_helper"

class ImageS3Test < UnitTestCase
  def test_basic_stuff
    s3 = ImageS3.new(
      server: "https://test.objects.com",
      bucket: "bucket",
      access_key_id: "xxxxxxxxxxxxxxxxxxxx",
      secret_access_key: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
      stub: true # (makes Aws::S3 return empty responses for everything)
    )
    s3.status("key")
    s3.list.each do |_obj|
      break
    end
    file = "#{Rails.root}/test/fixtures/robots.txt"
    s3.upload("key", file, content_type: "text/plain")
    File.open(file, "rb") do |fh|
      s3.upload("key", fh, content_type: "text/plain")
    end
    s3.delete("key")
  end
end
