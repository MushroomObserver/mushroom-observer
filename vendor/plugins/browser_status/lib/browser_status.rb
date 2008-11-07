#
#  = BrowserStatus
#
#  This helper provides a handy mechanism for retrieving important browser
#  stats.  Insert a line of code in the body of your layout template, and the
#  user's browser will report back to you whether they have cookies and
#  javascript enabled, and whether the session object is working properly.
#
#  1) Insert this line anywhere in the header of your layout template:
#
#    <%= check_if_user_turned_javascript_on %>
#
#  2) Enable this "before" filter in application_controller so that it runs
#  before anything else for every request:
#
#    class ApplicationController < ActionController::Base
#      before_filter :browser_status
#      ...
#
#  3) Now you have access to the following from your controllers and views:
#
#    session_new?        boolean: true if we've never seen this user before
#    session_working?    boolean: is session object working?
#    cookies_enabled?    boolean: are cookies enabled?
#    javascript_enabled? boolean: does browser have javascript enabled?
#    can_do_ajax?        boolean: can browser do AJAX?
#    is_robot?           boolean: did request come from robot?
#    is_text_only?       boolean: is browser text-only? (includes robots)
#    is_like_gecko?      boolean: is rendering engine Gecko or Gecko-like?
#    is_ie_compatible?   boolean: is rendering engine IE-compatible?
#
#    @js                 boolean: is javascript enabled?
#    @ua                 user agent: :ie, :firefox, :safari, :robot, :text, etc.
#    @ua_version         floating point number or nil
#
#  *Note*: <tt>session_new?</tt> should never return true, since if we've never
#  seen a user before, we'll force the first page we serve to redirect
#  immediately, no matter what the state of javascript or anything else.
#
#  = How it works
#
#  == Javascript
#
#  It starts with the hypothesis that javascript is off.  If that is wrong,
#  the first page it renders will redirect back to itself with the magic
#  parameter <tt>_js=on</tt> added to the URL.  This will inform the server
#  that javascript is on, and then it will serve the same page again without
#  the redirect.
#
#  It keeps track of which users have javascript turned on in the session.  It
#  is possible, however, that the session isn't working (e.g., cookies are
#  disabled).  It uses the IP address and user agent string to keep track of
#  users that don't have a session yet.  If the session isn't working, we store
#  the state in this static hash instead.  (It is cleaned out each time a new
#  user is found, and each time it learns that a user's session is working.
#  It only keeps stuff from the last 24 hours.)
#
#  To avoid the whole problem of file uploads and forms, we disable the
#  redirection if the request method is not +GET+.
#
#  *Note*: You can override the auto-detection thing altogether by setting
#  <tt>session[:js_override]</tt> to <tt>:on</tt> or <tt>:off</tt>.  This can
#  be used, for example, as a method to let the user explicitly tell your
#  server whether they want you to serve javascript-enabled pages or not, just
#  in case this mechanism fails for some users for whatever reason.
#
#  == Session
#
#  This is much easier.  We just check for a magic value in the session, and if
#  it's not there we assume the session isn't working properly.  The only
#  problem is that we won't find that magic value on the very first request
#  from a user (e.g. the first time the user loads the splash or intro page),
#  or possibly worse, if the user deep-links into your site, it could fail
#  potentially anywhere -- but only on the first request.
#
#  == Cookies
#
#  Cookies are handled the same way: we just check for a magic cookie on the
#  browser.  This will also fail the very first time a user comes to your site,
#  and whenever they clear or expire their cookies, just like above.
#
#  == Browser Type
#
#  We just look at <tt>request.env["HTTP_USER_AGENT"]</tt>.  We do not pretend
#  to catch all possibilities, just the major ones.  If you need finer control,
#  you will have to look at the environment string yourself.  See
#  http://www.zytrax.com/tech/web/browser_ids.htm for more details.
#
#  These are the types we handle, in rough order of popularity at my sites:
#    :robot      Web-crawlers for search engines, like Googlebot.
#    :firefox    Firefox.  (IE and Firefox are neck-and-neck, actually.)
#    :netscape   Netscape.  (Much like Firefox, but no one uses it any more.)
#    :ie         Internet Explorer.
#    :safari     Safari.
#    :opera      Opera.  (Very similar to IE... but not always.)
#    :chrome     Google Chrome.  (Very similar to Safari.)
#    :gecko      Others that use Gecko engine.  (Version is date: YYYYMMDD.nn)
#    :mozilla    Others that claim to be Mozilla-compatible (don't trust them!)
#    :other      Others that we don't know/care about.
#    :text       Text-only browsers like lynx, etc.
#
#
#
#  Author:: Jason Hollinger
#  License:: Free - do whatever you want to with it.
#  Last Update:: July 23, 2008
#
################################################################################

module BrowserStatus

  # Set this to true to bypass everything.  It will use the test profile below.
  TEST_SESSION_WORKING = true
  TEST_COOKIES_ENABLED = true
  TEST_JS              = true
  TEST_UA              = :firefox
  TEST_UA_VERSION      = 3.0

  # This is the minimal page that is served when a user first encounters the
  # site.  Subsequently, the session will store a cookie in the browser so that
  # they are recognized, and we won't ever have to do this again.  NOTE: no
  # attempt is made to make this XHTML compliant in the least.  As far as I
  # know it is impossible to do so.  (Way to go, W3C!)
  FIRST_PAGE = %(
    <html>
      <head>
        <script>
          window.location = '%s';
        </script>
      </head>
      <body>
        <noscript>
          <meta HTTP-EQUIV="REFRESH" content="0; url=%s">
        </noscript>
      </body>
    </html>
  )

  # Call this from the head or at the top of the body of your HTML template.
  # It inserts a command to reload the page if we think javascript is turned
  # off but find that it really is on.
  def check_if_user_turned_javascript_on

    # Reload page with special "_js=on" parameter to let us know that
    # Javascript is turned on in the user's browser.  There are a few
    # cases to be careful of: I ignore it on post of forms to avoid the
    # whole post data and file upload problem; and don't bother if the session
    # isn't working, since we won't be able to remember that JS is on, anyway.
    if !@js && !session[:js_override] && request.method == :get
      javascript_tag("window.location = '#{reload_with_args(:_js => 'on')}'")
    else
      ''
    end
  end

  # For backwards compatibility.
  alias :report_browser_status :check_if_user_turned_javascript_on

  # This is designed to be run as a before_filter at the top of
  # application_controller, before anthing else is run.  It sets several
  # "global" instance variables that are available to all controllers and
  # views.
  def browser_status

    # Create bogus browser for testing purposes.
    if RAILS_ENV == 'test'
      @session_working = TEST_SESSION_WORKING
      @cookies_enabled = TEST_COOKIES_ENABLED
      @js              = TEST_JS
      @ua              = TEST_UA
      @ua_version      = TEST_UA_VERSION
      return
    end

    ua = request.env['HTTP_USER_AGENT']
    ip = request.env['HTTP_X_FORWARDED_FOR'] ||
         request.env['HTTP_CLIENT_IP'] ||
         request.env['HTTP_REMOTE_ADDR']
    browser_id = "#{ip}|#{ua}"

    # Look up the user's browser.  We keep some minimal info about all browsers
    # that do not have a working session yet.
    @@our_session_cache ||= {}
    our_session = @@our_session_cache[browser_id]

    if session[:_x]

      # Session is working, clear entry from "our session" cache.
      session_new = false
      @session_working = true
      if our_session
        @@our_session_cache.delete(browser_id)
        clean_our_session_cache
      end

    else
      session[:_x] = true
      if our_session

        # Session is not working, but we've seen this browser before.
        session_new = false
        @session_working = false
        our_session[:time] = Time.now

      else

        # Session in not working, and we've never seen this browser before.
        session_new = true
        @session_working = nil
        our_session = @@our_session_cache[browser_id] = { :time => Time.now }
        clean_our_session_cache
      end
    end

    # Is javascript enabled?
    if session[:js_override]
      @js = (session[:js_override] == :on)
    elsif params[:_js]
      @js = (params[:_js] == 'on')
    elsif session[:_js] != nil
      @js = (session[:_js] == true)
    elsif our_session && our_session[:js] != nil
      @js = (our_session[:js] == true)
    else
      @js = nil
    end
    session[:_js] = @js
    our_session[:js] = @js if our_session

    # Are cookies enabled?
    if cookies[:_x]
      @cookies_enabled = true
    else
      cookies[:_x] = '1'
      @cookies_enabled = session_new ? nil : false
    end

    # What is the user agent?
    @ua, @ua_version = parse_user_agent(ua)

    # print "========================================\n"
    # print "browser_id       = [#{browser_id      }]\n"
    # print "session_new      = [#{session_new     }]\n"
    # print "@session_working = [#{@session_working}]\n"
    # print "@cookies_enabled = [#{@cookies_enabled}]\n"
    # print "@js              = [#{@js             }]\n"
    # print "@ua              = [#{@ua             }]\n"
    # print "@ua_version      = [#{@ua_version     }]\n"
    # print "HTTP_USER_AGENT  = [#{ua              }]\n"
    # print "params           = [#{params.inspect  }]\n"
    # print "========================================\n"

    # If we've never seen this user before, serve a tiny page that redirects
    # immediately to tell us the state of javascript, and lets us determine
    # whether session and cookies are woring correctly immediately.  (The
    # _new thing prevents infinite loops, just in case.)
    if session_new && params[:_new] != 'true'
      render(:text => FIRST_PAGE % [
        reload_with_args(:_js => 'on',  :_new => 'true'),
        reload_with_args(:_js => 'off', :_new => 'true'),
      ])
    end
  end

  # Have we seen this browser before?  Short-hand for <tt>@session_working == nil</tt>
  def session_new?
    @session_working == nil
  end

  # Is session working?  (i.e. are cookies enabled or whatever the +session+
  # object needs to work?)  Shorthand for <tt>@session_working</tt>.
  def session_working?
    @session_working
  end

  # Are cookies enabled on browser?  Doesn't determine if user is throwing
  # them away periodically, or whenever they close their browser.  Shorthand
  # for <tt>@cookies_enabled</tt>.
  def cookies_enabled?
    @cookies_enabled
  end

  # Is javascript enabled on browser?  Strictly speaking, it just checks if
  # the browser can do <tt>window.location = ...</tt>, but this is a good
  # proxy for checking if javascript is enabled at all.  You can also use
  # the instance variable <tt>@js</tt> for the same purpose.
  def javascript_enabled?
    @js
  end

  # Check to make sure browser can handle AJAX.  This doubles as a "will
  # prototype and scriptaculous work?" test, I believe.  The criteria clearly
  # need to be refined...
  def can_do_ajax?
    @js && (
      @ua == :ie       && @ua_version >= 5.5 ||
      @ua == :firefox  && @ua_version >= 1.0 ||
      @ua == :safari   && @ua_version >= 1.2 ||
      @ua == :opera    && @ua_version >= 0.0 ||
      @ua == :chrome   && @ua_version >= 0.0 ||
      @ua == :netscape && @ua_version >= 7.0
    )
  end

  # Check if the request came from a robot.
  def is_robot?
    @ua == :robot
  end

  # Check if browser's rendering engine is Gecko or Gecko-like (e.g. Safari).
  def is_like_gecko?
    [:firefox, :netscape, :safari, :chrome, :gecko].include? @ua
  end

  # Check if browser's rendering engine is IE-compatible (i.e. IE or Opera).
  def is_ie_compatible?
    [:ie, :opera].include? @ua
  end

  # Is browser text-only?  I'm throwing robots in here as well, since they
  # strip out formatting of all kinds.  You still need to serve important
  # images, though, as users will still want to be able to download them (and
  # robots need to be able to see them).  But it is helpful to simplify
  # formatting.
  def is_text_only?
    @ua == :text || @ua == :robot
  end

  # Take URL that got us to this page and add one or more parameters to it.
  # Returns new URL.
  #
  #   link_to("Next Page", reload_with_args(:page => 2))
  def reload_with_args(new_args)
    add_args_to_url(request.request_uri, new_args)
  end

  # Take an arbitrary URL and change the parameters.  Returns new URL.
  # Should even handle the fancy "/object/id" case.
  #
  #   url = url_for(:action => "blah", ...)
  #   new_url = add_args_to_url(url, :arg1 => :val1, :arg2 => :val2, ...)
  def add_args_to_url(url, new_args)
    args = {}

    # Parse parameters off of current URL.
    addr, parms = url.split('?')
    for arg in parms ? parms.split('&') : []
      var, val = arg.split('=')
      if var && var != ''
        var = CGI.unescape(var)
        # See note below about precedence in case of redundancy.
        args[var] = val if !args.has_key?(var)
      end
    end

    # Deal with the special "/object/45" => "/object/show?id=45" case.
    if match = addr.match(/\/(\d+)$/)
      # The "pseudo" arg takes precedence over "real" arg... that is, in the
      # url "/page/4?id=5", empirically Rails chooses the 4.  In fact, it seems
      # always to choose the left-most where there is redundancy.
      args['id'] = match[1]
      addr.sub!(/\/\d+$/, '')
      addr += '/show' if addr.match(/\/\/[^\/]+\/[^\/]+$/)
    end

    # Merge in new arguments, deleting where new values are nil.
    for var in new_args.keys
      val = new_args[var]
      var = var.to_s
      if val.nil?
        args.delete(var)
      elsif val.is_a?(ActiveRecord::Base)
        args[var] = val.id.to_s
      else
        args[var] = CGI.escape(val.to_s)
      end
    end

    # Put it back together.
    return addr if args.keys == []
    return addr + '?' + args.keys.sort.map \
        {|k| CGI.escape(k) + '=' + (args[k] || "")}.join('&')
  end

  # Parse the user_agent string from apache.  This does not catch everything.
  # But it should catch 99% of the browsers that hit your site.  See
  # http://www.zytrax.com/tech/web/browser_ids.htm
  #
  # Returns browser name and version:
  #   name, version = parse_user_agent(request.env['HTTP_USER_AGENT'])
  def parse_user_agent(ua)
    return [:other,    0.0    ] if ua.nil? || ua == '-'
    return [:text,     0.0    ] if ua.match(/^(Lynx|Links|ELinks|Dillo)/)
    return [:robot,    0.0    ] if ua.match(/http:|\w+@[\w\-]+\.\w+|robot|crawler|spider|slurp|googlebot|surveybot|webgobbler|morfeus|nutch|linkaider|linklint|linkwalker|metalogger|page-store|network diagnostics/i)
    return [:opera,    $1.to_f] if ua.match(/Opera[ \/](\d+\.\d+)/)
    return [:ie,       $1.to_f] if ua.match(/ MSIE (\d+\.\d+)/)
    return [:chrome,   $1.to_f] if ua.match(/Chrome\/(\d+\.\d+)/)
    return [:safari,   $1.to_f] if ua.match(/Version\/(\d+(\.\d+)?).*Safari/)
    return [:safari,   2.0    ] if ua.match(/Safari/)
    return [:firefox,  $1.to_f] if ua.match(/Firefox\/(\d+\.\d+)/)
    return [:iceweasel,$1.to_f] if ua.match(/Iceweasel\/(\d+\.\d+)/)
    return [:netscape, $1.to_f] if ua.match(/Netscape\/(\d+\.\d+)/)
    return [:gecko,    $1.to_f] if ua.match(/Gecko\/(\d{8})/)
    return [:mozilla,  $1.to_f] if ua.match(/Mozilla\/(\d+\.\d+)/)
    return [:other,    0.0    ]
  end

  private

  # Clean out old entries from "our_session" cache.
  def clean_our_session_cache
    cutoff = 1.hour.ago
    @@our_session_cache ||= {}
    @@our_session_cache.each_pair do |key, val|
      if val[:time] < cutoff
        @@our_session_cache.delete(key)
      end
    end
  end
end
