#  
#  = BrowserStatus
#  
#  This helper provides a handy mechanism for retrieving important browser
#  stats.  Insert a line of code in the body of your layout template, and the
#  user's browser will report back to you whether they have cookies and
#  javascript enabled, and whether the session object is working properly.
#  
#  1) Insert this line at the top of your layout's body:
#  
#    <body>
#      <%= report_browser_status %>
#      ...
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
#    cookies_enabled?   boolean: are cookies enabled?
#    session_working?   boolean: is session object working?
#    can_do_ajax?       boolean: can browser do AJAX?
#    is_robot?          boolean: did request come from robot?
#    is_text_only?      boolean: is browser text-only? (includes robots)
#    is_like_gecko?     boolean: is rendering engine Gecko or Gecko-like?
#    is_ie_compatible?  boolean: is rendering engine IE-compatible?
#
#    @js                boolean: is javascript enabled?
#    @ua                user agent: :ie, :firefox, :safari, :robot, :text, etc.
#    @ua_version        floating point number or nil
#
#  = How it works
#  
#  == Javascript
#  
#  It detects javascript by starting with the hypothesis that javascript is
#  off, then including a simple script in the page body that redirects back to
#  the same page with the magic parameter <tt>_js=on</tt> added to the URL.  If
#  we think, on the otherhand, that javascript is on, then we put a
#  <tt><noscript></tt> tag in there that does also redirects back to the same
#  page, this time with <tt>_js=off</tt> added to the URL.  It keeps the
#  current state stored in the session object. 
#  
#  There are a few things to be careful of.  If the session isn't persisting,
#  then we can't remember from one request to the next whether javascript is
#  on, so this trick would cause every single request to redirect one time.  To
#  avoid this, we disable the redirection if the session isn't working.  (See
#  below.)  This has the side-effect that we can't know whether javascript
#  is turned on or not until the _second_ request at earliest.
#  
#  Also, to avoid the whole problem of file uploads and forms, we disable the
#  redirection if the request method is not +GET+.  How often does the user
#  enable/disable javascript while filling out a form?  And don't they deserve
#  what they get if they do?
#  
#  *Note*: You can override this by setting <tt>session[:js_override]</tt> to
#  <tt>:on</tt> or <tt>:off</tt>.  This can be used, for example, as a method
#  to let the user explicitly tell your server whether they want you to serve
#  javascript-enabled pages or not, just in case this mechanism fails for some
#  users for whatever reason. 
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

  # Call this from within the body of your HTML page.  It inserts a command to
  # reload the page if we have the wrong hypothesis about whether javascript is
  # enabled on the browser or not.
  def report_browser_status

    # Reload page with special "_js_on" parameter to let us know that
    # Javascript is turned on in the user's browser.  There are a few
    # cases to be careful of: I ignore it on post of forms to avoid the
    # whole post data and file upload problem; and don't bother if cookies
    # are off, since we won't be able to remember that JS is on, anyway...
    # and it would result in *every* request reloading the page once.
    if @session_working && !@js && !session[:js_override] && request.method == :get
      javascript_tag("window.location = '#{reload_with_args(:_js => 'on')}'")

    # Just as important, if we think javascript is on but it isn't we do
    # the same thing in reverse, clearing the session flag.
    elsif @js && !session[:js_override] && request.method == :get
      %(<noscript><meta HTTP-EQUIV="REFRESH" content="0; url=#{
        reload_with_args(:_js => 'off')
      }"></noscript>)

    # Apparently actionview will sometimes crash if you return nil.
    else
      ""
    end
  end

  # This is designed to be run as a before_filter at the top of
  # application_controller, before anthing else is run.  It sets several
  # "global" instance variables that are available to all controllers and
  # views.
  def browser_status 

    # Is the session working?
    if session[:_working]
      @session_working = true
    else
      session[:_working] = true
    end

    # Are cookies enabled?
    if cookies[:_enabled]
      @cookies_enabled = true
    else
      cookies[:_enabled] = '1'
    end

    # Is javascript enabled?
    if session[:js_override]
      @js = (session[:js_override] == :on)
    elsif params[:_js]
      @js = (params[:_js] == 'on')
    elsif session[:_js] != nil
      @js = (session[:_js] == true)
    else
      # This is the initial assumption.
      @js = true
    end
    session[:_js] = @js

    # What is the user agent?
    env = request.env['HTTP_USER_AGENT']
    @ua, @ua_version = parse_user_agent(env)

    # print "------------------------------------\n"
    # print "@session_working = [#{@session_working}]\n"
    # print "@cookies_enabled = [#{@cookies_enabled}]\n"
    # print "@js              = [#{@js             }]\n"
    # print "@ua              = [#{@ua             }]\n"
    # print "@ua_version      = [#{@ua_version     }]\n"
    # print "HTTP_USER_AGENT  = [#{env             }]\n"
    # print "------------------------------------\n"
  end

  # Is javascript enabled on browser?  Strictly speaking, it just checks if
  # the browser can do <tt>window.location = ...</tt>, but this is a good
  # proxy for checking if javascript is enabled at all.  You can also use
  # the instance variable <tt>@js</tt> for the same purpose.
  def javascript_enabled?
    @js
  end

  # Are cookies enabled on browser?  Doesn't determine if user is throwing
  # them away periodically, or whenever they close their browser.  Shorthand
  # for <tt>@cookies_enabled</tt>.
  def cookies_enabled?
    @cookies_enabled
  end

  # Is session working?  (i.e. are cookies enabled or whatever the +session+
  # object needs to work?)  Shorthand for <tt>@session_working</tt>.
  def session_working?
    @session_working
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
    return [:netscape, $1.to_f] if ua.match(/Netscape\/(\d+\.\d+)/)
    return [:gecko,    $1.to_f] if ua.match(/Gecko\/(\d{8})/)
    return [:mozilla,  $1.to_f] if ua.match(/Mozilla\/(\d+\.\d+)/)
    return [:other,    0.0    ]
  end
end
