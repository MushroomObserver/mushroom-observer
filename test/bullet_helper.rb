# helper to integrate bullet gem with minitest
# from https://github.com/flyerhzm/bullet/issues/442
# Include this helper in any test file where you want to use the gem
# Usage:
#  class <YourTest> < <YourTestCase>
#    include(BulletHelper)
module BulletHelper
  def before_setup
    Bullet.start_request
    super if defined?(super)
  end

  def after_teardown
    super if defined?(super)

    Bullet.perform_out_of_channel_notifications if Bullet.notification?
    Bullet.end_request
  end
end
