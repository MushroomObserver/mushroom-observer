# encoding: utf-8
#
#  = Configuration
#
#  This is essentially the "boot" script for the application.  (See below for
#  the precise order in which files are included and run.)
#
#  Configurations in this file will affect all three modes: PRODUCTION,
#  DEVELOPMENT and TEST.  They can be overridden with mode-specific
#  configurations in these three files:
#
#  * config/environments/production.rb
#  * config/environments/development.rb
#  * config/environments/test.rb
#
#  Make site-specific modifcations in these files:
#
#  * config/consts-site.rb
#  * config/environment-site.rb
#  * config/environments/production-site.rb
#  * config/environments/development-site.rb
#  * config/environments/test-site.rb
#
#  == Startup Procedure
#
#  [1. script/server]
#    Runs config/boot.rb, then runs commands/server (in rails gem).
#
#  [2. config/boot.rb]
#    Loads rubygems, loads rails gem, sets load path, DOES NOT RUN ANYTHING.
#
#  [3. commands/server]
#    Picks server and runs it.
#
#  [4. commands/servers/webrick]
#    Parses ARGV, runs config/environment.rb, runs server.
#
#  [5. config/environment.rb]
#    Does all the application-supplied configuration, in this order:
#    1. config/consts-site.rb (optional)
#    2. config/consts.rb
#    3. config/environment.rb
#    4. config/environment-site.rb (optional)
#    5. config/environments/RAILS_ENV.rb
#    6. config/environments/RAILS_ENC-site.rb (optional)
#
#  == Global Constants
#
#  Global Constants (e.g., DOMAIN and DEFAULT_LOCALE) are initialized in
#  config/consts.rb.
#
#  == Rails Configurator
#
#  The environment files are evaled in the context of a Rails::Initializer
#  instance.  The "local" variable +config+ gives you access to the
#  Rails::Configuration class.  This, among other things, lets you set class
#  variables in all the major Rails packages:
#
#    # This sets @@default_timezone in ActiveRecord::Base.
#    config.active_record.default_timezone = :utc
#
#  Global constants _can_ be defined in these configurator blocks, too.  Rails
#  automatically copies them into the Object class namespace (thereby making
#  them available to the entire application).  However, currently, no global
#  constants are defined this way -- they are defined outside, directly in the
#  main namespace.
#
################################################################################

# Make sure it's already booted.
require File.join(File.dirname(__FILE__), 'boot')

# This must be here -- config/boot.rb greps this file looking for it(!!)
RAILS_GEM_VERSION = '2.1.1'

# Short-hand for the three execution modes.
PRODUCTION  = (RAILS_ENV == 'production')
DEVELOPMENT = (RAILS_ENV == 'development')
TESTING     = (RAILS_ENV == 'test')

# The default engine for ruby 1.9.3 is 'psych', but it can't handle utf-8 any more.
# However 'syck' is still apparently available, and even though it prints out a
# bunch of gobbledygook for non-ascii characters, it at least works and is fast.
require 'yaml'
YAML::ENGINE.yamler = 'syck'

# Should be one of [:normal, :silent]
# :silent turns off event logging and email notifications
class RunLevel
  @@runlevel = :normal
  def self.normal()
    @@runlevel = :normal
  end
  
  def self.silent()
    @@runlevel = :silent
  end
  
  def self.is_normal?()
    @@runlevel == :normal
  end
end

# RUN_LEVEL = :normal # :silent

# Do site-specific global constants first.
file = File.join(File.dirname(__FILE__), 'consts-site')
require file if File.exists?(file + '.rb')

# Now provide defaults for the rest.
require File.join(File.dirname(__FILE__), 'consts')

# --------------------------------------------------------------------
#  General non-mode-specific, non-site-specific configurations here.
# --------------------------------------------------------------------

# Sacraficial goat and rubber chicken to get Globalite to behave correctly
# for rake tasks.
:some_new_symbol

Rails::Initializer.run do |config|

  # Add our local classes and modules (e.g., Textile and LoginSystem) and class
  # extensions (e.g., String and Symbol extensions) to the include path.
  config.load_paths += %W(
    #{RAILS_ROOT}/app/classes
    #{RAILS_ROOT}/app/extensions
  )

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake create_sessions_table')
  # config.action_controller.session_store = :active_record_store

  # A secret is required to generate an integrity hash for cookie session data.
  config.action_controller.session = {
    :session_key => 'mo_session',
    :secret => '1f58da43b4419cd9c1a7ffb87c062a910ebd2925d3475aefe298e2a44d5e86541125c91c2fb8482b7c04f7dd89ecf997c09a6e28a2d01fc4819c75d2996e6641'
  }

  # Enable page/fragment caching by setting a file-based store (remember to
  # create the caching directory and make it readable to the application) .
  # config.action_controller.fragment_cache_store = :file_store, "#{RAILS_ROOT}/cache"

  # Make Active Record use UTC instead of local time.  This is critical if we
  # want to sync up remote servers.  It causes Rails to store dates in UTC and
  # convert from UTC to whatever we've set the timezone to when reading them
  # back in.  It shouldn't actually make any difference how the database is
  # configured.  It takes dates as a string, stores them however it chooses,
  # performing whatever conversions it deems fit, then returns them back to us
  # in exactly the same format we gave them to it.  (NOTE: only the first line
  # should be necessary, but for whatever reason, Rails is failing to do the
  # other configs on some platforms.)
  config.time_zone = ENV['TZ']
  if config.time_zone.nil?
    # Localization isn't loaded yet.
    raise 'TZ environment variable must be set. Run "rake -D time" for a list of tasks for finding appropriate time zone names.'
  end

  # This instructs ActionView how to mark form fields which have an error.
  # I just change the CSS class to "has_error", which gives it a red border.
  # This is superior to the default, which encapsulates the field in a div,
  # because that throws the layout off.  Just changing the border, while less
  # conspicuous, has no effect on the layout.
  config.action_view.field_error_proc = Proc.new { |html_tag, instance|
    html_tag.sub(/(<\w+)/, '\1 class="has_error"')
  }

  # Configure SMTP settings for ActionMailer.
  config.action_mailer.smtp_settings = MAIL_CONFIG

  # Include optional site-specific configs.
  file = __FILE__.sub(/.rb$/, '-site.rb')
  eval(IO.read(file), binding, file) if File.exists?(file)
end

# -------------------------------------
#  "Temporary" third-party bug-fixes.
# -------------------------------------

# Get rid of ?<timestamp> so caching works better.
# See http://www.deathy.net/blog/2007/06/26/rails-asset-timestamping-and-why-its-bad/ for more details.
ENV['RAILS_ASSET_ID'] = ''

# This should move the error templates 404.html and 500.html so that Passenger will no longer
# try to serve them instead of observations if the user requests mo.org/404 or mo.org/500.
# Copied from lines 146-164 in action_controller/rescue.rb.  Seems hacky, but if you read
# the comments at the head of this file, this was the expected method of customizing error
# handling in Rails(!)
module ActionController
  class Base
    def rescue_action_in_public(exception)
      status = interpret_status(response_code_for_rescue(exception))
      path = ERROR_PAGE_FILES.sub(/NNN/, status[0,3])
      if File.exist?(path)
        render :file => path, :status => status
      else
        head status
      end
    end
  end
end

# RedCloth 4.x has quite a few bugs still. This should roughly fix them until
# Jason Garber has time to fix them properly in the parser rules. :stopdoc:
module RedCloth
  class TextileDoc
    def to_html(*rules)

      # Pre-filters: losing square brackets if next to quotes, this
      # introduces a space -- not perfect, but close.
      self.gsub!('["', '[ "')
      self.gsub!('"]', '" ]')

      apply_rules(rules)
      result = to(RedCloth::Formatters::HTML).to_s.clone

      # Post-filters: not catching all the itallics, and seeing spans where
      # they don't belong.
      result.gsub!(/(^|\W)_+([A-Z][A-Za-z0-9]+)_+(\W|$)/, '\\1<i>\\2</i>\\3')
      result.gsub!(/<span>(.*?)<\/span>/, '%\\1%')

      return result
    end
  end
end

# There appears to be a bug in read_multipart.  I checked, this is never used
# by the live server.  But it *is* used by integration tests, and it fails
# hideously if you are foolish enough to try to upload a file in such tests.
# Apparently it simply forgot to unescape the parameter names.  Easy fix. -JPH
module ActionController
  class AbstractRequest
    class << self
      alias fubar_read_multipart read_multipart
      def read_multipart(*args)
        params = fubar_read_multipart(*args)
        new_params = {}
        for key, val in params
          new_params[URI.unescape(key)] = val
        end
        return new_params
      end
    end
  end
end

# Add the option to "orphan" attachments if you use ":dependent => :orphan" in
# the has_many association options.  This has the effect of doing *nothing* to
# the attachements.  The other options allowed by Rails already are:
#
#   :delete_all   Delete directly from database without callbacks.
#   :destroy      Call "destroy" on all attachments.
#   nil           Set the parent id to NULL.
#
# New option:
#
#   :orphan       Do nothing.
#
module ActiveRecord
  module Associations
    class HasManyAssociation
      alias original_delete_records delete_records
      def delete_records(records)
        if @reflection.options[:dependent] != :orphan
          original_delete_records(records)
        end
      end
    end
    module ClassMethods
      alias original_configure_dependency_for_has_many configure_dependency_for_has_many
      def configure_dependency_for_has_many(reflection)
        if reflection.options[:dependent] != :orphan
          original_configure_dependency_for_has_many(reflection)
        end
      end
    end
  end
end

# This fixes a long-known bug in eager-loading mechanism in Active Record.
module ActiveRecord
  module AssociationPreload
    module ClassMethods
      def preload_associations(records, associations, preload_options={})
        records = [records].flatten.compact.uniq
        return if records.empty?
        case associations
        when Array then associations.each {|association| preload_associations(records, association, preload_options)}
        when Symbol, String then preload_one_association(records, associations.to_sym, preload_options)
        when Hash then
          associations.each do |parent, child|
            raise "parent must be an association name" unless parent.is_a?(String) || parent.is_a?(Symbol)
            preload_one_association(records, parent.to_sym, preload_options)
            ########## WAS: preload_associations(records, parent, preload_options) ##########
            reflection = reflections[parent]
            parents = records.map {|record| record.send(reflection.name)}.flatten.reject(&:nil?)
            ########## WAS: parents = records.map {|record| record.send(reflection.name)}.flatten ##########
            unless parents.empty? || parents.first.nil?
              parents.first.class.preload_associations(parents, child)
            end
          end
        end
      end
    end
  end
end

################################################################################
# Stuff to get rails 2.1.1 working with ruby 1.9. -Jason, Feb 2011

# No longer allowing Ruby 1.8. Sorry. Pain in the ass to get the database
# adapter to work for it.
if RUBY_VERSION < '1.9'
  raise "MO requires ruby version 1.9"
end

# Need this to force encoding of views to all be utf-8.  (Rails 3 makes this
# globally configurable using 'config.encoding'.)
module ActionView
  module TemplateHandlers
    module Compilable
      alias _old_create_template_source create_template_source
      def create_template_source(*args)
        result = _old_create_template_source(*args)
        result.force_encoding('utf-8') if result.respond_to?(:force_encoding)
        return result
      end
    end
  end
end

# This is used by ym4r_gm plugin.
module ActionController
  class Base
    def self.relative_url_root
      ''
    end
  end
end

# This must have something to do with ruby 1.9.
module Ym4r
  module GmPlugin
    class Variable
      alias to_str to_s
    end
  end
end

# Near as I can tell there is simply a bug in the Rails 2.1.1 handling of
# encodings in assert_select.  It forces the text it's validating to be the
# same encoding as the selector.  This is fine if the selector is a string,
# because the selector takes on the source encoding of the caller's file, so
# we have control over it.  But Ruby second-guesses us when it creates regexen.
# They do NOT take on the encoding of the source file -- they are implictly
# downgraded to US-ASCII if no 8-bit characters are used.  This causes rails
# force the encoding of the text to US-ASCII, as well, causing it to crash.
# I can find no way to solve this problem without recasting the regexen with
# the following sleight of hand.  Ugly, but it works.
require 'action_controller'
require 'action_controller/assertions'
module ActionController
  module Assertions
    module SelectorAssertions
      alias __old_assert_select assert_select
      def assert_select(*args, &block)
        args = args.map do |arg|
          case arg
          when Regexp ; /#{arg}/u
          when String ; arg.force_encoding('UTF-8')
          else        ; arg
          end
        end
        __old_assert_select(*args, &block)
      end
    end
  end
end 

# This is used by passenger?
module ActionController
  class Base
    X_POWERED_BY = 'X-Powered-By'
  end
end

# This is a known bug in old ActionMailer versions.
module ActionMailer
  class Base
    def perform_delivery_smtp(mail)
      destinations = mail.destinations
      mail.ready_to_send
      sender = mail['return-path'] || mail['from'] # <-- instead of "mail.from"
      Net::SMTP.start(smtp_settings[:address], smtp_settings[:port], smtp_settings[:domain],
          smtp_settings[:user_name], smtp_settings[:password], smtp_settings[:authentication]) do |smtp|
        smtp.sendmail(mail.encoded, sender, destinations)
      end
    end
  end
end

# The test-unit plugin now provides this, but fails to give it all the same
# functionality of assert_match (ability to pass String instead of Regexp, in
# particular). 
gem 'test-unit'
require 'test/unit/assertions.rb' unless defined? Unit::Test::Assertions
module Test
  module Unit
    module Assertions
      def assert_not_match(expect, actual, msg=nil)
        _wrap_assertion do
          expect = Regexp.new(expect) if expect.is_a?(String)
          msg = build_message(msg, "Expected <?> not to match <?>.", actual, expect)
          assert_block(msg) { actual !~ expect }
        end
      end
    end
  end
end

# Multipart form data is read in as ASCII-8BIT / BINARY.  Apparently we can
# usually assume that it is actually UTF-8, so we just need to force the
# correct encoding.
module ActionController
  class AbstractRequest
    class << self
      alias __get_typed_value get_typed_value
      def get_typed_value(value)
        result = __get_typed_value(value)
        result.force_encoding('utf-8') if result.respond_to?(:force_encoding)
        return result
      end
    end
  end
end

# This tells browsers which encoding to use when sending POST data from forms.
# The magic hidden field is a workaround to force IE to pay attention to the
# requested character encoding.
module ActionView
  module Helpers
    module FormTagHelper
      alias __form_tag_html form_tag_html
      def form_tag_html(args)
        __form_tag_html(args.merge(:'accept-charset' => 'UTF-8')) +
          '<input name="_utf8" type="hidden" value="&#9731;" />'
      end
    end
  end
end

# It will crash when rendering the error template in development mode if there
# is any non-ASCII text in the source code.
require 'action_view/template_error'
module ActionView
  class TemplateError
    alias __source_extract source_extract
    def source_extract(*args)
      __source_extract(*args).force_encoding('utf-8')
    end
  end
end

################################################################################
# Stuff to get rails 2.1.1 working with ruby 1.9.3 -Jason, May 2012

MissingSourceFile::REGEXPS.push([/^cannot load such file -- (.+)$/i, 1])

# Ruby 1.8.6 introduced new! and deprecated new0.
# Ruby 1.9.0 removed new0.
# Ruby trunk revision 31668 removed the new! method.
if !DateTime.respond_to?(:new!) and
   !DateTime.respond_to?(:new0)
  class DateTime
    HALF_DAYS_IN_DAY = Rational.new!(1, 2)
    def self.new!(ajd = 0, of = 0, sg = Date::ITALY)
      jd = ajd + of + HALF_DAYS_IN_DAY
      jd_i = jd.to_i
      jd_i -= 1 if jd < 0
      hours = (jd - jd_i) * 24
      hours_i = hours.to_i
      minutes = (hours - hours_i) * 60
      minutes_i = minutes.to_i
      seconds = (minutes - minutes_i) * 60
      DateTime.jd(jd_i, hours_i, minutes_i, seconds, of, sg)
    end
  end
end

# Without this, queries like current_account.tickets.recent.count would
# instantiate AR objects for all (!!) tickets in the account, not merely
# return a count of the recent ones.  See:
# https://rails.lighthouseapp.com/projects/8994/tickets/5410-multiple-database-queries-when-chaining-named-scopes-with-rails-238-and-ruby-192
# (The patch in that lighthouse bug was not, in fact, merged in).
module ActiveRecord
  module Associations
    class AssociationProxy
      def respond_to_missing?(meth, incl_priv)
        false
      end
    end
  end
end

# Make sure the flash sets the encoding to UTF-8. (I must have missed this. Found it at:
# http://developer.uservoice.com/entries/how-to-upgrade-a-rails-2.3.14-app-to-ruby-1.9.3/)
module ActionController
  module Flash
    class FlashHash
      def [](k)
        v = super
        v.is_a?(String) ? v.force_encoding("UTF-8") : v
      end
    end
  end
end

# To get rid of an annoying warning message:
# Change actionpack-2.1.1/lib/action_view/helpers/text_helper.rb line 467 to:
#   (?:/(?:[~\w\+@%=\(\)-]|(?:[,.;:'][^\s$]))*)*

