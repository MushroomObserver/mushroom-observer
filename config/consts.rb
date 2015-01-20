# encoding: utf-8
MushroomObserver::Application.configure do

  # Ensure that these are defined in case we're executing this script on its own
  # (e.g., to provide access to configs for bash sripts).
  config.root = File.expand_path("../..", __FILE__)
  config.env  = ENV["RAILS_ENV"]

  # List of alternate server domains.  We redirect from each of these to the real one.
  config.bad_domains = []

  # Base URL of the source repository.
  config.code_repository = "https://github.com/MushroomObserver"

  # Date after which votes become public.
  config.vote_cutoff = "19000101"

  # Code appended to ids to make "sync_id".  Must start with letter.
  config.server_code = "XX"

  # Default locale when nothing sets it explicitly.
  config.default_locale = "en"

  # I18n namespace all our app-specific translations are kept in inside localization files.
  config.locale_namespace = "mo"

  # Make Active Record use UTC instead of local time.  This is critical if we
  # want to sync up remote servers.  It causes Rails to store dates in UTC and
  # convert from UTC to whatever we've set the timezone to when reading them
  # back in.  It shouldn't actually make any difference how the database is
  # configured.  It takes dates as a string, stores them however it chooses,
  # performing whatever conversions it deems fit, then returns them back to us
  # in exactly the same format we gave them to it.  (NOTE: only the first line
  # should be necessary, but for whatever reason, Rails is failing to do the
  # other configs on some platforms.)
  config.time_zone = 'America/New_York'

  # Date/time formats for website UI.
  config.web_date_format = "%Y-%m-%d"
  config.web_time_format = "%Y-%m-%d %H:%M:%S %Z (%z)"

  # Date/time formats for API XML responses.
  config.api_date_format = "%Y-%m-%d"
  config.api_time_format = "%Y-%m-%d %H:%M:%S"

  # Date/time formats for emails.
  config.email_date_format = "%Y-%m-%d"
  config.email_time_format = "%Y-%m-%d %H:%M:%S %Z (%z)"

  # Default theme for users not logged in, new users and robots.
  config.default_theme = "BlackOnWhite"

  # Available themes.
  config.themes = %w( Agaricus Amanita Cantharellaceae Hygrocybe BlackOnWhite )

  # Queued email only gets delivered if you have run the rake task email:send.
  # script/send_email is a cron script for running email:send.  (Delay is in
  # seconds.)
  config.queue_email        = false
  config.email_per_minute   = 25
  config.email_num_attempts = 3
  config.email_log          = "#{config.root}/log/email_error.log"
  config.email_queue_delay  = 5

  # Default email addresses.
  config.news_email_address        = "news@mushroomobserver.org"
  config.noreply_email_address     = "no-reply@mushroomobserver.org"
  config.accounts_email_address    = "webmaster@mushroomobserver.org"
  config.error_email_address       = "webmaster@mushroomobserver.org"
  config.webmaster_email_address   = "webmaster@mushroomobserver.org"
  config.exception_recipients      = "webmaster@mushroomobserver.org"
  config.extra_bcc_email_addresses = ""

  # File where the list of most commonly used names lives.
  config.name_primer_cache_file = "#{config.root}/tmp/name_primer.#{config.env}"
  config.user_primer_cache_file = "#{config.root}/tmp/user_primer.#{config.env}"

  # File where we keep name_lister data cache.
  config.name_lister_cache_file = "#{config.root}/public/assets/name_list_data.js"

  # Access data for Pivotal Tracker's API.
  config.pivotal_enabled  = false
  config.pivotal_url      = "www.pivotaltracker.com"
  config.pivotal_path     = "/services/v5"
  config.pivotal_project  = "224629"
  config.pivotal_token    = "xxx"
  config.pivotal_max_vote = 1
  config.pivotal_min_vote = -1
  config.pivotal_test_id  = 77165602

  # Configuration files for location validator.
  config.location_countries_file = "#{config.root}/config/location/countries.yml"
  config.location_states_file    = "#{config.root}/config/location/states.yml"
  config.location_prefixes_file  = "#{config.root}/config/location/prefixes.yml"
  config.location_bad_terms_file = "#{config.root}/config/location/bad_terms.yml"

  # Limit the number of objects we draw on a google map.
  config.max_map_objects = 100

  # Where images are kept locally until they are transferred.
  config.local_image_files = "#{config.root}/public/images"

  # Definition of image sources.  Keys are :test, :read and :write.  Values are
  # URLs.  Leave :write blank for read-only sources.  :transferred_flag tells MO
  # to test for existence of file by using image#transferred flag.
  # config.image_sources = {
  #   :local => {
  #     :test => "file://#{config.local_image_files}",
  #     :read => "/images",
  #   },
  #   :cdmr => {
  #     :test => :transferred_flag,
  #     :read => "http://images.digitalmycology.com",
  #   }
  # }

  # Search order when serving images.  Key is size, e.g., :thumbnail, :small, etc.
  # config.image_precedence = {
  #   :default => [:local, :cdmr]
  # }
  # config.image_fallback_source = :cdmr

  # Array of sizes to be kept on the web server, e.g., :thumbnail, :small, etc.
  config.keep_these_image_sizes_local = []

  # Location of script used to process and transfer images.
  # (Set to nil to have it do nothing.)
  config.process_image_command = "#{config.root}/script/process_image <id> <ext> <set>"

  # Limit size of image uploads (ImageMagick bogs down on large images).
  config.image_upload_max_size = 20000000

  # Flag intended for controller when the debugger gets invoked.
  # Use with lines like: debugger if MO.debugger_flag
  config.debugger_flag = false
end
