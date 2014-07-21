# encoding: utf-8
#
#  = Functional Test Case
#
#  The test case class that all functional tests currently derive from.
#  Includes: 
#
#  1. Some general-purpose helpers and assertions from GeneralExtensions.
#  2. Some controller-related helpers and assertions from ControllerExtensions.
#  3. A few helpers that encapsulate testing the flash error mechanism.
#
################################################################################

class FunctionalTestCase < ActionController::TestCase
  include GeneralExtensions
  include FlashExtensions
  include ControllerExtensions

  # Temporary hacks to check for unsafe html.
  alias _old_get_ get
  alias _old_post_ post
  alias _old_put_ put
  alias _old_delete_ delete
  def get(*args, &block)
    _old_get_(*args, &block)
    check_for_unsafe_html
  end
  def post(*args, &block)
    _old_post_(*args, &block)
    check_for_unsafe_html
  end
  def put(*args, &block)
    _old_put_(*args, &block)
    check_for_unsafe_html
  end
  def delete(*args, &block)
    _old_delete_(*args, &block)
    check_for_unsafe_html
  end
  @@file_num = 0
  def check_for_unsafe_html
    str = @response.body.to_s.force_encoding('utf-8')
    if str[0..4] == '<!DOC'
      str.gsub!(/<!--.*?-->/mu, '')
      str.gsub!(/<!\[CDATA\[.*?\]\]>/mu, '')
      if str.match(/&lt;[a-z]+|&amp;[#\w]+;/i)
        @@file_num += 1
        path = "#{Rails.root}/unsafe"
        if File.directory?(path)
          file = "#{path}/#{@controller.class}_#{@@file_num}.html"
          # File.open(file, 'w') {|f| f.write(@response.body)}
          File.open(file, 'w') {|f| f.write(str)}
        end
      end
    end
  end
end
