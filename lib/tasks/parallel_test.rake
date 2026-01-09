# frozen_string_literal: true

namespace :parallel do
  namespace :test do
    desc "Set up MySQL config files for parallel testing"
    task setup: :environment do
      service = ParallelTestConfigService.new
      result = service.setup_config_files
      exit 1 unless result
    end

    desc "Clean up MySQL config files for parallel testing"
    task cleanup: :environment do
      service = ParallelTestConfigService.new
      result = service.cleanup_config_files
      exit 1 unless result
    end
  end
end
