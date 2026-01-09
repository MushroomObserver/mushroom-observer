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

namespace :db do
  desc "Load schema with FK checks disabled (for SolidQueue compatibility)"
  task schema_load_no_fk: :environment do
    ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS=0")
    Rake::Task["db:schema:load"].invoke
    ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS=1")
  end
end
