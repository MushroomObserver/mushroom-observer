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
DOMAIN       = 'localhost'                               if !defined? DOMAIN
HTTP_DOMAIN  = "http://#{DOMAIN}:3000"                   if !defined? HTTP_DOMAIN
IMAGE_DOMAIN = "#{HTTP_DOMAIN}/images"                   if !defined? IMAGE_DOMAIN
BAD_DOMAINS  = ['localhost.localdomain:3000']            if !defined? BAD_DOMAINS

# Where images are kept.
IMG_DIR      = "#{RAILS_ROOT}/public/images"             if !TESTING && !defined? IMG_DIR
IMG_DIR      = "#{RAILS_ROOT}/public/test_images"        if TESTING  && !defined? IMG_DIR
TEST_IMG_DIR = "#{RAILS_ROOT}/public/test_images"        if !defined? TEST_IMG_DIR

# Code appended to ids to make 'sync_id'.  Must start with letter.
SERVER_CODE = 'XX'                                       if !defined? SERVER_CODE

# Default locale when nothing sets it explicitly.
DEFAULT_LOCALE = 'en-US'                                 if !defined? DEFAULT_LOCALE

# Date/time formats for website UI.
WEB_DATE_FORMAT = '%Y-%m-%d'                             if !defined? WEB_DATE_FORMAT
WEB_TIME_FORMAT = '%Y-%m-%d %H:%M:%S %Z (%z)'            if !defined? WEB_TIME_FORMAT

# Date/time formats for API XML responses.
API_DATE_FORMAT = '%Y-%m-%d'                             if !defined? API_DATE_FORMAT
API_TIME_FORMAT = '%Y-%m-%dT%H:%M:%S'                    if !defined? API_TIME_FORMAT

# Date/time formats for emails.
EMAIL_DATE_FORMAT = '%Y-%m-%d'                           if !defined? EMAIL_DATE_FORMAT
EMAIL_TIME_FORMAT = '%Y-%m-%d %H:%M:%S %Z (%z)'          if !defined? EMAIL_TIME_FORMAT

# Queued email only gets delivered if you have run the rake task email:send.
# script/send_email is a cron script for running email:send.  (Delay is in
# seconds.)
QUEUE_EMAIL        = false                               if !defined? QUEUE_EMAIL
EMAIL_PER_MINUTE   = 25                                  if !defined? EMAIL_PER_MINUTE
EMAIL_NUM_ATTEMPTS = 3                                   if !defined? EMAIL_NUM_ATTEMPTS
EMAIL_LOG          = "#{RAILS_ROOT}/log/email_error.log" if !defined? EMAIL_LOG
QUEUE_DELAY        = 5                                   if !defined? QUEUE_DELAY

# Important email addresses.
NEWS_EMAIL_ADDRESS        = "news@#{DOMAIN}"             if !defined? NEWS_EMAIL_ADDRESS
NOREPLY_EMAIL_ADDRESS     = "no-reply@#{DOMAIN}"         if !defined? NOREPLY_EMAIL_ADDRESS
ACCOUNTS_EMAIL_ADDRESS    = "accounts@#{DOMAIN}"         if !defined? ACCOUNTS_EMAIL_ADDRESS
ERROR_EMAIL_ADDRESS       = "errors@#{DOMAIN}"           if !defined? ERROR_EMAIL_ADDRESS
WEBMASTER_EMAIL_ADDRESS   = "webmaster@#{DOMAIN}"        if !defined? WEBMASTER_EMAIL_ADDRESS
EXTRA_BCC_EMAIL_ADDRESSES = ""                           if !defined? EXTRA_BCC_EMAIL_ADDRESSES
EXCEPTION_RECIPIENTS      = "webmaster@#{DOMAIN}"        if !defined? EXCEPTION_RECIPIENTS

# File where the list of most commonly used names lives.
NAME_PRIMER_CACHE_FILE = "#{RAILS_ROOT}/tmp/name_primer.#{RAILS_ENV}" if !defined? NAME_PRIMER_CACHE_FILE
USER_PRIMER_CACHE_FILE = "#{RAILS_ROOT}/tmp/user_primer.#{RAILS_ENV}" if !defined? USER_PRIMER_CACHE_FILE

# File where we keep name_lister data cache.
NAME_LISTER_CACHE_FILE = "#{RAILS_ROOT}/public/javascripts/name_list_data.js" if !defined? NAME_LISTER_CACHE_FILE

# Limit size of image uploads (ImageMagick bogs down on large images).
IMAGE_UPLOAD_MAX_SIZE = 20000000                         if !defined? IMAGE_UPLOAD_MAX_SIZE

# Stylesheets available.
CSS = %w(Agaricus Amanita Cantharellaceae Hygrocybe)     if !defined? CSS

# URL of the subversion source repository.
SVN_REPOSITORY = "http://svn.collectivesource.com/mushroom_sightings" if !defined? SVN_REPOSITORY

# Date after which votes become public.
VOTE_CUTOFF = '20100401'                                 if !defined? VOTE_CUTOFF

# Mail configuration.  Moved here to allow easy site-specific configuration
# by overriding in config/consts-site.rb.
MAIL_CONFIG = {
  :address        => 'localhost',
  :port           => 25,
  :domain         => DOMAIN,

  # To use Dreamhost mailserver to send mail:
  # :address        => 'mail.mushroomobserver.org',
  # :port           => 587,
  # :domain         => 'mushroomobserver.org',
  # :authentication => :login,
  # :user_name      => 'mo@mushroomobserver.org',
  # :password       => 'xxx',
} if !defined? MAIL_CONFIG

# Access data for Pivotal Tracker's API.
PIVOTAL_URL      = 'www.pivotaltracker.com'              if !defined? PIVOTAL_URL
PIVOTAL_PATH     = '/services/v3'                        if !defined? PIVOTAL_PATH
PIVOTAL_USERNAME = 'username'                            if !defined? PIVOTAL_USERNAME
PIVOTAL_PASSWORD = 'password'                            if !defined? PIVOTAL_PASSWORD
PIVOTAL_PROJECT  = 'project_id'                          if !defined? PIVOTAL_PROJECT
PIVOTAL_MAX_VOTE = 1                                     if !defined? PIVOTAL_MAX_VOTE
PIVOTAL_MIN_VOTE = -1                                    if !defined? PIVOTAL_MIN_VOTE
PIVOTAL_CACHE    = RAILS_ROOT + '/tmp/pivotal'           if !defined? PIVOTAL_CACHE
