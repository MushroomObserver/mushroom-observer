# encoding: utf-8
#
#  = Global Constants
#
#  This file provides default values for all our application-wide global
#  constants.
#
#  *NOTE*: This file is version-controlled, so any changes you make here will
#  propogate to all the other servers around the world.  If you need to
#  override any of these values locally, please do so here, instead:
#
#    config/consts-site.rb
#
################################################################################

# Various server domains.
DOMAIN       = 'localhost' if not defined? DOMAIN
HTTP_DOMAIN  = "http://#{DOMAIN}:3000"
IMAGE_DOMAIN = "http://#{DOMAIN}:3000/images"
BAD_DOMAINS  = ['localhost.localdomain:3000']

# Where images are kept.
IMG_DIR      = "#{RAILS_ROOT}/public/" + (TESTING ? 'test_images' : 'images')
TEST_IMG_DIR = "#{RAILS_ROOT}/public/test_images"

# Code appended to ids to make 'sync_id'.  Must start with letter.
SERVER_CODE = 'XX'

# Default locale when nothing sets it explicitly.
DEFAULT_LOCALE = 'en-US'

# Time zone of the server.  This is only used in logs(?)
SERVER_TIME_ZONE = 'America/New_York'

# Date/time formats for website UI.
WEB_DATE_FORMAT = '%Y-%m-%d'
WEB_TIME_FORMAT = '%Y-%m-%d %H:%M:%S %Z (%z)'

# Date/time formats for API XML responses.
API_DATE_FORMAT = '%Y-%m-%d'
API_TIME_FORMAT = '%Y-%m-%d %H:%M:%S'

# Date/time formats for emails.
EMAIL_DATE_FORMAT = '%Y-%m-%d'
EMAIL_TIME_FORMAT = '%Y-%m-%d %H:%M:%S %Z (%z)'

# Queued email only gets delivered if you have run the rake task email:send.
# script/send_email is a cron script for running email:send.  (Delay is in
# seconds.)
QUEUE_EMAIL        = false
EMAIL_PER_MINUTE   = 25
EMAIL_NUM_ATTEMPTS = 3
EMAIL_LOG          = "#{RAILS_ROOT}/log/email_error.log"
QUEUE_DELAY        = 5

# Important email addresses.
NEWS_EMAIL_ADDRESS        = "news@#{DOMAIN}"
NOREPLY_EMAIL_ADDRESS     = "no-reply@#{DOMAIN}"
ACCOUNTS_EMAIL_ADDRESS    = "webmaster@#{DOMAIN}"
ERROR_EMAIL_ADDRESS       = "webmaster@#{DOMAIN}"
WEBMASTER_EMAIL_ADDRESS   = "webmaster@#{DOMAIN}"
EXCEPTION_RECIPIENTS      = "webmaster@#{DOMAIN}"
EXTRA_BCC_EMAIL_ADDRESSES = ""

# File where the list of most commonly used names lives.
NAME_PRIMER_CACHE_FILE = "#{RAILS_ROOT}/tmp/name_primer.#{RAILS_ENV}"
USER_PRIMER_CACHE_FILE = "#{RAILS_ROOT}/tmp/user_primer.#{RAILS_ENV}"

# File where we keep name_lister data cache.
NAME_LISTER_CACHE_FILE = "#{RAILS_ROOT}/public/javascripts/name_list_data.js"

# Location of HTML pages to serve on error.
ERROR_PAGE_FILES = "#{RAILS_ROOT}/public/error_NNN.html"

# Limit size of image uploads (ImageMagick bogs down on large images).
IMAGE_UPLOAD_MAX_SIZE = 20000000

# Limit the number of objects we draw on a google map.
MAX_MAP_OBJECTS = 100

# Stylesheets available.
CSS = %w(Agaricus Amanita Cantharellaceae Hygrocybe BlackOnWhite)

# URL of the subversion source repository.
SVN_REPOSITORY = "http://svn.collectivesource.com/mushroom_sightings"

# Date after which votes become public.
VOTE_CUTOFF = '20100401'

# Mail configuration.  Moved here to allow easy site-specific configuration
# by overriding in config/consts-site.rb.
MAIL_CONFIG = {
  :address        => 'localhost',
  :port           => 25,
  :domain         => DOMAIN,
}

# Access data for Pivotal Tracker's API.
PIVOTAL_URL      = 'www.pivotaltracker.com'
PIVOTAL_PATH     = '/services/v3'
PIVOTAL_USERNAME = 'username'
PIVOTAL_PASSWORD = 'password'
PIVOTAL_PROJECT  = 'project_id'
PIVOTAL_MAX_VOTE = 1
PIVOTAL_MIN_VOTE = -1
PIVOTAL_CACHE    = RAILS_ROOT + '/tmp/pivotal'

# Configuration files for location validator.
LOCATION_COUNTRIES_FILE = "#{RAILS_ROOT}/config/location/countries.yml"
LOCATION_STATES_FILE    = "#{RAILS_ROOT}/config/location/states.yml"
LOCATION_PREFIXES_FILE  = "#{RAILS_ROOT}/config/location/prefixes.yml"
LOCATION_BAD_TERMS_FILE = "#{RAILS_ROOT}/config/location/bad_terms.yml"

