# Settings specified here will take precedence over those in config/environment.rb

# The test environment is used exclusively to run your application's
# test suite.  You never need to work with it otherwise.  Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs.  Don't rely on the data there!
config.cache_classes = true

# Log error messages when you accidentally call methods on nil.
config.whiny_nils    = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching             = false

# Tell ActionMailer not to deliver emails to the real world.
# The :test delivery method accumulates sent emails in the
# ActionMailer::Base.deliveries array.
config.action_mailer.delivery_method = :test

IMG_DIR = File.join(RAILS_ROOT, 'public', 'test_images')

DOMAIN = 'http://localhost:3000'
IMAGE_DOMAIN = 'http://localhost:3000/images'

TESTING = true

# Queued email only gets delivered if you have run the rake
# task email:send.  script/send_email is a cron script
# for running email:send.
QUEUE_EMAIL = false
EMAIL_PER_MINUTE = 25
EMAIL_NUM_ATTEMPTS = 3
EMAIL_LOG = RAILS_ROOT + '/log/email_error.log'
QUEUE_DELAY = 5.seconds

# File where the list of most commonly used names lives.
NAME_PRIMER_CACHE_FILE = "#{RAILS_ROOT}/tmp/name_primer.test"

# Limit size of image uploads (ImageMagick bogs down on large images).
IMAGE_UPLOAD_MAX_SIZE = 20000000

