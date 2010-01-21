# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/switchtower.rake, and they will automatically be available to Rake.

require(File.join(File.dirname(__FILE__), 'config', 'boot'))

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

require 'tasks/rails'

Rake::RDocTask.new { |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "MushroomObserver"
  rdoc.rdoc_files.include(
    'README', 'README_*',
    'app', 'lib',
    # 'script/update_images',
    # 'script/process_image',
    'vendor/plugins/acts_as_versioned/lib',
    'vendor/plugins/browser_status/lib',
    # 'vendor/plugins/classic_pagination/lib',
    # 'vendor/plugins/enum-column/lib',
    # 'vendor/plugins/exception_notification/lib',
    'vendor/plugins/fastercsv/lib',
    # 'vendor/plugins/globalite/lib',
    'vendor/plugins/ruby-rtf/lib'
    # 'vendor/plugins/ym4r/lib',
  )
}
