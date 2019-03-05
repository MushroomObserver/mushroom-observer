require "aws-sdk"

class ImageS3
  # Initialize connection:
  #
  #   s3 = ImageS3.new(
  #     server: "https://objects.dreamhost.com",
  #     bucket: "mo-images",
  #     access_key_id: "xxx",
  #     secret_access_key: "xxx"
  #   )
  #
  def initialize(opts)
    @server            = opts[:server]
    @bucket            = opts[:bucket]
    @access_key_id     = opts[:access_key_id]
    @secret_access_key = opts[:secret_access_key]
    @stub              = !!opts[:stub]
  end

  # Returns object you can call "each" on to iterate over all files in store:
  #
  #   s3.list.each do |obj|
  #     puts obj.key, obj.content_length, obj.content_type, etc.
  #   end
  #
  def list
    Results.new(client.list_objects(bucket: @bucket))
  rescue Aws::S3::Errors::Http503Error
    raise "#{@server} temporarily unavailable"
  rescue StandardError => e
    raise "Unable to get directory of S3 bucket #{@bucket} at #{@server}: #{e}"
  end
  class Results
    def initialize(pager)
      @pager = pager
    end

    def each(&block)
      @pager.each do |response|
        response.contents.each(&block)
      end
    rescue Aws::S3::Errors::Http503Error
      raise "#{@server} temporarily unavailable"
    end
  end

  # Upload a single object:
  #
  #  s3.upload(key, file_name_or_handle,
  #    content_type: "image/jpeg",
  #    content_md5: md5sum(file)
  #  )
  #
  def upload(key, file, opts = {})
    io = File.open(file, "r") unless file.is_a?(IO)
    client.put_object(
      opts.merge(bucket: @bucket,
                 key: key,
                 acl: "public-read",
                 body: io)
    ).data
  rescue Aws::S3::Errors::Http503Error
    raise "#{@server} temporarily unavailable"
  rescue StandardError => e
    raise "Unable to upload image #{key} to S3 bucket #{@bucket} "\
          "at #{@server}: #{e}"
  end

  # Get basic info about one object, returns nil if doesn't exist:
  #
  #   info = s3.status(key)
  #   puts info.content_length, info.content_type, etc.
  #
  def status(key)
    client.head_object(
      bucket: @bucket,
      key: key
    ).data
  rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
    nil
  rescue Aws::S3::Errors::Http503Error
    raise "#{@server} temporarily unavailable"
  rescue StandardError => e
    raise "Unable to get info on #{key} from S3 bucket #{@bucket} "\
          "at #{@server}: #{e.class.name}: #{e}"
  end

  # Delete one object:
  #
  #   s3.delete(key)
  #
  def delete(key)
    client.delete_object(
      bucket: @bucket,
      key: key
    )
  rescue Aws::S3::Errors::Http503Error
    raise "#{@server} temporarily unavailable"
  rescue StandardError => e
    raise "Unable to delete image #{key} from S3 bucket #{@bucket} "\
          "at #{@server}: #{e}"
  end

  def client
    @s3 ||= Aws::S3::Client.new(
      endpoint: @server,
      credentials: Aws::Credentials.new(@access_key_id, @secret_access_key),
      region: "us-east-1",
      stub_responses: @stub
    )
  rescue StandardError => e
    raise "couldn't establish connection: #{e}"
  end
end
