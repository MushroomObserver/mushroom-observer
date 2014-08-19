# Override these defaults.
DOMAIN         = 'mushroomobserver.org'
HTTP_DOMAIN    = 'http://mushroomobserver.org'
IMAGE_DOMAIN   = "#{HTTP_DOMAIN}/images"
SERVER_CODE    = 'us1'
DEFAULT_LOCALE = 'en-US'
BAD_DOMAINS    = ["www.#{DOMAIN}"]

# Use queued email mechanism.
QUEUE_EMAIL = true

# Nathan wants to be BCC'ed on every single email.
EXTRA_BCC_EMAIL_ADDRESSES = "mo@collectivesource.com"

# Date after which votes become public.
VOTE_CUTOFF = '20100405'

# Set timezone?
ENV['TZ'] = 'Eastern Time (US & Canada)'

# Use gmail server to send email.
MAIL_CONFIG = {
  :address => "smtp.gmail.com",
  :port => 587,
  :authentication => :plain,
  :enable_starttls_auto => true,
  :user_name => "webmaster@mushroomobserver.org",
  :password => "xxx"
}

# Configuration for accessing Pivotal Tracker project.
PIVOTAL_PROJECT  = '224629'
PIVOTAL_TEST_ID  = '77165602'
PIVOTAL_USERNAME = 'webmaster@mushroomobserver.org'
PIVOTAL_PASSWORD = 'xxx'

IMAGE_SOURCES = {
  :local => {
    :test => "file://#{LOCAL_IMAGE_FILES}",
    :read => "/local_images"
  },
  :cdmr => {
    :test  => :transferred_flag,
    :read  => "/images",
    :write => "ssh://cdmr@digitalmycology.com:images.digitalmycology.com"
  }
  # For use when testing live server in parallel with production server.
  # :mo = {
  #   :test  => "http://mushroomobserver.org/local_images",
  #   :read  => "http://mushroomobserver.org/local_images",
  #   :write => "ssh://jason@mushroomobserver.org:/var/web/mo/public/images",
  # }
}

IMAGE_PRECEDENCE = {
  :default   => [:cdmr, :local]
  # For use when testing live server in parallel with production server.
  # :default   => [:cdmr, :local, :mo]
}
