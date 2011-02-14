#
#  = Base Test Case
#
#  Does some basic site-wide configuration for all the tests.  This is part of
#  the base class that all unit tests must derive from.
#
#  *NOTE*: This must go directly in Test::Unit::TestCase because of how Rails
#  tests work. 
#
################################################################################

class Test::Unit::TestCase

  # Register standard app-wide setup and teardown hooks.  (See below.)
  setup    :application_setup
  teardown :application_teardown

  # Load all fixtures -- this is only done once thanks to transactional
  # fixtures (see below), so there is little penalty for loading them all
  # outside of a small delay at start-up. 
  fixtures :all

  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  #
  # [I have tested the difference, this is *HUGE*.  It also works flawlessly.
  # with no apparent drawbacks, never making any tests run any slower. -JPH]
  self.use_transactional_fixtures = true

  # Do NOT use instantiated fixtures.  This buys a *significant* amount of
  # performance.  I have left the five users instantiated, though, see below
  # in +application_setup+.
  self.use_instantiated_fixtures = false

  # Tell the damned tester not to run test methods in a random order!!!
  # Makes debugging complex interactions absolutely impossible.  Honestly,
  # isn't the world random enough as it is??  Who thought this was a good
  # idea??
  # def self.test_order
  #   :not_random!
  # end

  # Standard setup to run before every test.  Sets the locale, timezone,
  # and makes sure User doesn't think a user is logged in.  It also
  # places instances of all the test users in +@rolf+, +@mary+, etc.
  def application_setup
    Locale.code = :'en-US' if Locale.code != :'en-US'
    Time.zone = 'America/New_York'
    User.current = nil
    @rolf, @mary, @junk, @dick, @katrina, @roy = User.all
  end

  # Standard teardown to run after every test.  Just makes sure any
  # images that might have been uploaded are cleared out.
  def application_teardown
    if File.exists?(IMG_DIR)
      FileUtils.rm_rf(IMG_DIR)
    end
  end
end
