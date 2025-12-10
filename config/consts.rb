# frozen_string_literal: true

require("yaml")

class ImageConfigData
  attr_reader :config

  def initialize
    root = File.expand_path("..", __dir__)
    @env = ENV.fetch("RAILS_ENV", "development")
    @config = YAML.load_file("#{root}/config/image_config.yml")[@env]
    make_paths_worker_specific! if parallel_test_mode?
  end

  private

  def parallel_test_mode?
    # Rails sets TEST_ENV_NUMBER for parallel test workers
    # It's "" for worker 0, "2" for worker 1, "3" for worker 2, etc.
    @env == "test" && ENV.key?("TEST_ENV_NUMBER")
  end

  def worker_suffix
    # TEST_ENV_NUMBER is "" for worker 0, "2" for worker 1, "3" for worker 2, etc.
    worker_id = ENV["TEST_ENV_NUMBER"]
    worker_id.empty? ? "0" : worker_id
  end

  def make_paths_worker_specific!
    # Update local_image_files path
    @config["local_image_files"] = append_worker_suffix(@config["local_image_files"])

    # Update image_sources paths
    @config["image_sources"]&.each do |_source_name, source_config|
      %i[test read write].each do |key|
        next unless source_config[key].is_a?(String)
        next if source_config[key] == ":transferred_flag"

        source_config[key] = append_worker_suffix(source_config[key])
      end
    end
  end

  def append_worker_suffix(path)
    # Don't modify URLs or special flags
    return path if path.start_with?("https://", "http://") || path == ":transferred_flag"

    # Handle file:// URLs and regular paths
    if path.start_with?("file://")
      prefix = "file://"
      actual_path = path.sub(/^file:\/\//, "")
    else
      prefix = ""
      actual_path = path
    end

    # Append worker suffix to test_images, test_server paths
    modified_path = actual_path.gsub(
      /(test_images|test_server\d+)(?=\/|$)/,
      "\\1-#{worker_suffix}"
    )

    "#{prefix}#{modified_path}"
  end
end

IMAGE_CONFIG_DATA = ImageConfigData.new

MushroomObserver::Application.configure do
  # Ensure that these are defined in case we're executing this script
  # on its own (e.g., to provide access to configs for bash sripts).
  config.root = File.expand_path("..", __dir__)
  config.env  = ENV.fetch("RAILS_ENV", nil)

  # List of alternate server domains.  We redirect from each of these
  # to the real one.
  config.bad_domains = []

  config.site_name = "Mushroom Observer"
  config.domain = "mushroomobserver.org"
  config.http_domain = "https://mushroomobserver.org"

  # Base URL of the source repository.
  config.code_repository = "https://github.com/MushroomObserver"

  # Date after which votes become public.
  config.vote_cutoff = "19000101"

  # Code appended to ids to make "sync_id".  Must start with letter.
  config.server_code = "XX"

  # Default locale when nothing sets it explicitly.
  config.default_locale = "en"

  # I18n namespace all our app-specific translations are kept in
  # inside localization files.
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
  config.time_zone = "America/New_York"

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
  config.themes = %w[Agaricus Amanita Cantharellaceae Hygrocybe BlackOnWhite]

  # Queued email only gets delivered if you have run the rake task email:send.
  # script/send_email is a cron script for running email:send.  (Delay is in
  # seconds.)
  config.queue_email        = false
  config.email_per_minute   = 25
  config.email_num_attempts = 3
  config.email_log          = "#{config.root}/log/email_error.log"
  config.email_queue_delay  = 5

  # Default email addresses.
  config.news_email_address = "news@#{config.domain}"
  config.noreply_email_address = "no-reply@#{config.domain}"
  config.accounts_email_address = "webmaster@#{config.domain}"
  config.webmaster_email_address = "webmaster@#{config.domain}"
  config.donation_business = "UQ23P3G6FBYKN"

  # File where we keep name_lister data cache.
  config.name_lister_cache_file =
    "#{config.root}/app/javascript/src/name_list_data.js"

  # Configuration files for location validator.
  location_path = "#{config.root}/config/location/"
  config.location_continents_file = "#{location_path}continents.yml"
  config.location_countries_file = "#{location_path}countries.yml"
  config.location_states_file    = "#{location_path}states.yml"
  config.location_prefixes_file  = "#{location_path}prefixes.yml"
  config.location_bad_terms_file = "#{location_path}bad_terms.yml"
  config.unknown_location_name = "Earth"
  config.obs_location_max_area = 24_000
  # Geographic epsilon for bounding box comparisons (~11 meters at equator).
  # Used for: rounding tolerance, point vs box threshold, minimal box size.
  config.box_epsilon = 0.0001

  # Limit the number of objects we draw on a google map.
  config.max_map_objects = 100

  # Where images are kept locally until they are transferred.
  # In test environment with parallel workers, paths include worker ID to avoid conflicts
  config.local_image_files = format(
    IMAGE_CONFIG_DATA.config["local_image_files"], root: MO.root
  )

  # Definition of image sources.  Keys are :test, :read and :write.  Values are
  # URLs.  Leave :write blank for read-only sources.  :transferred_flag tells MO
  # to test for existence of file by using image#transferred flag.
  config.image_sources = IMAGE_CONFIG_DATA.config["image_sources"]

  # Search order when serving images.
  # Key is size, e.g., :thumbnail, :small, etc.
  # config.image_precedence = {
  #   :default => [:local, :mycolab]
  # }
  # config.image_fallback_source = :mycolab

  # Array of sizes to be kept on the web server, e.g., :thumbnail, :small, etc.
  config.keep_these_image_sizes_local =
    IMAGE_CONFIG_DATA.config["keep_these_image_sizes_local"]

  # We transfer originals to cloud archive storage right away, but we keep
  # them on the image server for as long as we can, deleting them in batches.
  # All images with `id >= next_image_id_to_go_to_cloud` are still being served
  # from the image server. NOTE: this number must be kept in sync with the
  # nginx configuration!
  config.next_image_id_to_go_to_cloud = 0

  # This is where original images from cloud storage are temporarily cached.
  config.local_original_image_cache_path = "#{config.root}/public/orig_cache"
  config.local_original_image_cache_url = "/orig_cache"

  # Maximum number of original images per day a user is allowed to download.
  config.original_image_user_quota = 100
  config.original_image_site_quota = 10_000

  # Cloud storage bucket name.
  config.image_bucket_name = "mo-image-archive-bucket"

  # Location of script used to process and transfer images.
  # (Set to nil to have it do nothing.)
  config.process_image_command =
    "#{config.root}/script/process_image <id> <ext> <set> <strip> &"

  # Limit size of image uploads (ImageMagick bogs down on large images).
  config.image_upload_max_size = 20_971_520 # 20*1024*1024 = 20 Mb

  # Files used to prevent abuse of server.
  config.blocked_ips_file = "#{config.root}/config/blocked_ips.txt"
  config.okay_ips_file = "#{config.root}/config/okay_ips.txt"
  config.ip_stats_file = "#{config.root}/log/ip_stats.txt"

  # Flag intended for controller when the debugger gets invoked.
  # Use with lines like: debugger if MO.debugger_flag
  config.debugger_flag = false

  # Watch objects with comment wars between these two sets of users.
  config.water_users = []
  config.oil_users   = []

  # List of IP addresses to blacklist no longer in Rails
  # Instead will be handled in Iptables

  # Default "secret key", see rails docs.
  config.secret_key_base = "a" * 30

  # EOL parameters.
  config.eol_ranks = %w[
    Form Variety Subspecies Genus Family Order Class Phylum Kingdom
  ]
  config.eol_ranks_for_export = %w[Form Variety Subspecies Species Genus]
  config.eol_min_image_vote = 2
  config.eol_min_observation_vote = 2.4

  # Default number of items for an RSS page
  config.default_layout_count = 12

  # Max number of results Query will put in "IN (...)" clauses.  This
  # was originally 1000, but searching for "Russula" or "Amanita" now
  # exceeds that limit (Dec. 2024) and is causing issues.  Raising it
  # to 10,000 allows those cases to work.  Tested a simple query with
  # 11,000 ids on the current version of MySQL which completed in
  # around 0.1 seconds.
  config.query_max_array = 10_000

  # Filter(s) to apply to all Querys
  config.default_content_filter = nil

  # Maximum number of Observations that can be downloaded in a single request
  config.max_downloads = 5000

  # List of User ids of users that can see the image recognition
  # "Suggest Names" button on the observation page.
  config.image_model_beta_testers = [103_233]

  # Header for print_labels RTF file.
  config.label_rtf_header_file = "#{config.root}/public/label_header.rtf"
end
