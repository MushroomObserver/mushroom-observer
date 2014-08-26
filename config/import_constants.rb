APP_ROOT = File.expand_path('../..', __FILE__)

PRODUCTION  = (ENV["RAILS_ENV"] == 'production')
DEVELOPMENT = (ENV["RAILS_ENV"] == 'development')
TESTING     = (ENV["RAILS_ENV"] == 'test')

def import_constants(file)
  file = File.join(File.dirname(__FILE__), file)
  if File.exists?(file)
    Module.new do
      class_eval File.read(file, :encoding => 'utf-8')
      for const in constants
        unless Object.const_defined?(const)
          Object.const_set(const, const_get(const))
        end
      end
    end
  end
end

import_constants('consts-site.rb')
import_constants('consts.rb')
