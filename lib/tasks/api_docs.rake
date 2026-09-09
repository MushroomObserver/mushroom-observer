# frozen_string_literal: true

# Shared by the api:openapi tasks below.
module ApiDocsTasks
  module_function

  def dir
    Rails.public_path.join("api-docs")
  end

  # The ?v= content hash in index.html's spec-url busts the browser
  # cache -- public/ files are served with a long max-age, so without
  # it a regenerated spec can go unseen for days.
  def version_stamp(yaml)
    "openapi.yaml?v=#{Digest::MD5.hexdigest(yaml)[0, 8]}"
  end

  def stamp_index(yaml)
    index = dir.join("index.html")
    html = File.read(index)
    unless html.match?(/openapi\.yaml\?v=\w*/)
      abort("#{index} has no openapi.yaml?v= token to stamp -- restore " \
            "the ?v= query on the spec-url.")
    end
    File.write(index, html.sub(/openapi\.yaml\?v=\w*/, version_stamp(yaml)))
  end

  def fresh?(yaml)
    yaml_path = dir.join("openapi.yaml")
    index_path = dir.join("index.html")
    File.exist?(yaml_path) && File.read(yaml_path) == yaml &&
      File.exist?(index_path) &&
      File.read(index_path).include?(version_stamp(yaml))
  end
end

namespace :api do
  desc "Generate the OpenAPI 3.1 spec for API2 into public/api-docs/"
  task openapi: :environment do
    require "fileutils"
    FileUtils.mkdir_p(ApiDocsTasks.dir)
    yaml = API2::OpenapiSpec.to_yaml
    File.write(ApiDocsTasks.dir.join("openapi.yaml"), yaml)
    ApiDocsTasks.stamp_index(yaml)
    puts("Wrote #{ApiDocsTasks.dir.join("openapi.yaml")} " \
         "(#{API2::OpenapiSpec::RESOURCES.size} resources, " \
         "#{ApiDocsTasks.version_stamp(yaml)}).")
  end

  desc "Fail if public/api-docs/ is stale vs the code"
  task openapi_check: :environment do
    if ApiDocsTasks.fresh?(API2::OpenapiSpec.to_yaml)
      puts("api-docs are up to date.")
    else
      abort("api-docs are stale. Run `bin/rails api:openapi` and commit.")
    end
  end
end
