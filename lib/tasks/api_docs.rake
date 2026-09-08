# frozen_string_literal: true

namespace :api do
  desc "Generate the OpenAPI 3.1 spec for API2 into public/api-docs/"
  task openapi: :environment do
    require "fileutils"
    dir = Rails.public_path.join("api-docs")
    FileUtils.mkdir_p(dir)
    path = dir.join("openapi.yaml")
    File.write(path, API2::OpenapiSpec.to_yaml)
    puts("Wrote #{path} (#{API2::OpenapiSpec::RESOURCES.size} resources).")
  end

  desc "Fail if public/api-docs/openapi.yaml is stale vs the code"
  task openapi_check: :environment do
    path = Rails.public_path.join("api-docs/openapi.yaml")
    current = File.exist?(path) ? File.read(path) : ""
    if current == API2::OpenapiSpec.to_yaml
      puts("openapi.yaml is up to date.")
    else
      abort("openapi.yaml is stale. Run `bin/rails api:openapi` and commit.")
    end
  end
end
