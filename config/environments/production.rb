# Settings specified here will take precedence over those in config/environment.rb

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = true

# Use a different logger for distributed setups
# config.logger        = SyslogLogger.new


# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host                  = "http://assets.example.com"

# Disable delivery errors if you bad email addresses should just be ignored
# config.action_mailer.raise_delivery_errors = false

DOMAIN = 'http://mushroomobserver.org'

TESTING = false

# Queued email only gets delivered if you have run the rake
# task email:send.  script/send_email is a cron script
# for running email:send.
QUEUE_EMAIL = true
EMAIL_PER_MINUTE = 25
QUEUE_DELAY = 5.minutes

# Enable this only on the production server.  It tells the image uploader to
# write images to the image server at images.mushroomobserver.org.
IMAGE_TRANSFER = false
IMAGE_SERVER = 'velosa@images.mushroomobserver.org:images.mushroomobserver.org'
