# Be sure to restart your web server when you modify this file.

class MemoryProfiler
  DEFAULTS = {:delay => 10, :string_debug => false}

  def self.start(opt={})
    opt = DEFAULTS.dup.merge(opt)
        
    Thread.new do
      prev = Hash.new(0)
      curr = Hash.new(0)
      curr_strings = []
      delta = Hash.new(0)

      file = File.open('log/memory_profiler.log','w')
      string_file = File.open('log/memory_profiler_strings.log', 'w')

      no_change = false
      need_dump = false
      
      loop do
        begin
          GC.start
          curr.clear

          curr_strings = [] if opt[:string_debug]

          ObjectSpace.each_object do |o|
            curr[o.class] += 1 #Marshal.dump(o).size rescue 1
            if opt[:string_debug] and o.class == String
              curr_strings.push o
            end
          end

          if opt[:string_debug]
            if need_dump and no_change
              string_file.puts "@@@@ #{Time.now} @@@@\n"
              curr_strings.sort.each do |s|
                string_file.puts s
              end
              string_file.flush
              need_dump = false
              no_change = false
              file.puts "* dumped strings *\n" if opt[:string_debug]
              file.flush
            end
            curr_strings.clear
          end

          delta.clear
          (curr.keys + delta.keys).uniq.each do |k,v|
            delta[k] = curr[k]-prev[k]
          end

          no_change = true
          file.puts "Top 20"
          delta.sort_by { |k,v| -v.abs }[0..19].sort_by { |k,v| -v}.each do |k,v|
            if v != 0
              file.printf "%+5d: %s (%d)\n", v, k.name, curr[k]
              no_change = false
              need_dump = true
            end
          end
          file.puts "no_change: #{no_change}, need_dump: #{need_dump}"
          file.flush

          delta.clear
          prev.clear
          prev.update curr
          GC.start
        rescue Exception => err
          STDERR.puts "** memory_profiler error: #{err}"
        end
        sleep opt[:delay]
      end
    end
  end
end

# MemoryProfiler.start(:string_debug => true)

# Uncomment below to force Rails into production mode when 
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

# Add a shared file for consts that are not configuration dependent
require File.join(File.dirname(__FILE__), 'consts')

# Get rid of ?<timestamp> so caching works better.  See
# http://www.deathy.net/blog/2007/06/26/rails-asset-timestamping-and-why-its-bad/
# for more details
ENV["RAILS_ASSET_ID"] = ""

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence those specified here
  
  # Skip frameworks you're not going to use
  # config.frameworks -= [ :action_web_service, :action_mailer ]

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Force all environments to use the same logger level 
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake create_sessions_table')
  # config.action_controller.session_store = :active_record_store

  # A secret is required to generate an integrity hash for cookie session data.
  if RAILS_GEM_VERSION >= '2.0'
    config.action_controller.session = {
      :session_key => 'mo_session',
      :secret => '1f58da43b4419cd9c1a7ffb87c062a910ebd2925d3475aefe298e2a44d5e86541125c91c2fb8482b7c04f7dd89ecf997c09a6e28a2d01fc4819c75d2996e6641'
    }
  end

  # Enable page/fragment caching by setting a file-based store
  # (remember to create the caching directory and make it readable to the application)
  # config.action_controller.fragment_cache_store = :file_store, "#{RAILS_ROOT}/cache"

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc
  
  # Use Active Record's schema dumper instead of SQL when creating the test database
  # (enables use of different database adapters for development and test environments)
  # config.active_record.schema_format = :ruby

  # See Rails::Configuration for more options
end

# Add new inflection rules using the following format 
# (all these examples are active by default):
# Inflector.inflections do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   inflect.irregular 'person', 'people'
#   inflect.uncountable %w( fish sheep )
# end

# Include your application configuration below
