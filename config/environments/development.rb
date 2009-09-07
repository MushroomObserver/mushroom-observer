# Settings specified here will take precedence over those in config/environment.rb

# In the development environment your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the webserver when you make code changes.
config.cache_classes     = false

# Log error messages when you accidentally call methods on nil.
config.whiny_nils        = true

# Enable the breakpoint server that script/breakpointer connects to
if RAILS_GEM_VERSION < '2.0'
  config.breakpoint_server = true
end

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching             = false

# Don't care if the mailer can't send
config.action_mailer.raise_delivery_errors = false

# Tell ActionMailer not to deliver emails to the real world.
# The :file delivery method accumulates sent emails in the
# ../mail directory.  (This is a feature I added. -JPH 20080213)
config.action_mailer.delivery_method = :file

DOMAIN = 'http://localhost:3000'

TESTING = false

# Queued email only gets delivered if you have run the rake
# task email:send.  script/send_email is a cron script
# for running email:send.
QUEUE_EMAIL = true
EMAIL_PER_MINUTE = 25
EMAIL_NUM_ATTEMPTS = 3
EMAIL_LOG = RAILS_ROOT + '/log/email_error.log'
QUEUE_DELAY = 5.seconds

# File where the list of most commonly used names lives.
NAME_PRIMER_CACHE_FILE = "#{RAILS_ROOT}/tmp/name_primer.development"

# Limit size of image uploads (ImageMagick bogs down on large images).
IMAGE_UPLOAD_MAX_SIZE = 20000000

# Temporary switch to let us quickly back out changes to how image uploads are processed.
NEW_IMAGE_THINGY = true
