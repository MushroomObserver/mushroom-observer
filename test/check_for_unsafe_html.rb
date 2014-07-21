# encoding: utf-8
#
#  = Check for Unsafe HTML
#
#  This file adds a little bit of code at the end of every get/post request
#  to ensure that no unsafe HTML has slipped by.
#
################################################################################

class FunctionalTestCase < ActionController::TestCase
  # Add a bit of code after each get/post/put/delete request to check for unsafe HTML.
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

  def check_for_unsafe_html
    unless @unsafe_html_filter_disabled
      str = @response.body.to_s.force_encoding('utf-8')
      if str[0..4] == '<!DOC'
        str.gsub!(/<!--.*?-->/mu, '')
        str.gsub!(/<!\[CDATA\[.*?\]\]>/mu, '')
        if str.match(/&lt;[a-z]+|&amp;[#\w]+;/i)
          msg = '...' + $`[-200..-1] + '***HERE***' + $& + $'[0..200] + '...'
          assert_block("Unsafe HTML found! Here's the appropriate part of the HTML page:\n" + msg + "\n") {false}
        end
      end
    end
  end

  def disable_unsafe_html_filter(value=true)
    @unsafe_html_filter_disabled = value
  end
end
