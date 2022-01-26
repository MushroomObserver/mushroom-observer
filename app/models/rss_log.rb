# frozen_string_literal: true

#  = RSS Log Model
#
#  This model handles the RSS feed.  Every object we care about gets an RssLog
#  instance to report changes in that object.  Going forward, every new object
#  gets assigned one; historically, there are loads of objects without, but we
#  don't really care, so they stay that way until they are updated.
#
#  There is a separate <tt>#{object}_id</tt> field for each kind of object that
#  can own an RssLog.  I thought it would be cleaner to use a polymorphic
#  association, however that makes it impossible to eager-load different
#  associations for the different types of owners.  The resulting performance
#  hit was significant.
#
#  Possible owners are currently:
#
#  * Location
#  * Name
#  * Observation
#  * Project
#  * SpeciesList
#  * GlossaryTerm
#  * Article
#
#  == Adding RssLog to Model
#
#  I think this is relatively easy.  Try following these steps:
#
#  1) Add columns to rss_logs and new model tables via migration:
#
#       class AddRssLogToModel < ActiveRecord::Migration
#         def self.up
#           add_column(:rss_logs, :model_id, :integer)
#           add_column(:models, :rss_log_id, :integer)
#         end
#         def self.down
#           remove_column(:rss_logs, :model_id)
#           remove_column(:models, :rss_log_id)
#         end
#       end
#
#  2) Inform model of the new association: (automatically inherits +log+
#     method from AbstractModel)
#
#       belongs_to :rss_log
#
#  3) Inform RssLog of the new association:
#
#       (just search for "location" in this file)
#
#  4) Add partial view for +list_rss_logs+:
#
#       (just clone, e.g., app/views/observer/_location.rhtml)
#
#  5) Add "show log" link at bottom of model's show page:
#
#       <%= show_object_footer(@object) %>
#
#  6) Add +by_rss_log+ flavor to Query for your model:
#
#       self.allowed_model_flavors = {
#         :Model => [
#           :by_rss_log, # Models with RSS logs, in RSS order.
#         ]
#       }
#
#  Above is somewhat dated. Also:
#  Inform model which events to log:
#        self.autolog_events = [:created!, :updated!]
#  Inform model how to display its name when logging created and destroyed
#         def unique_format_name
#         def format_name
#
#
#  == Usage
#
#  AbstractModel provides a standardized interface for all models that handle
#  RssLog (see the list above).  These are inherited automatically by any model
#  that contains an "rss_log_id" column.
#
#    rss_log = observation.rss_log
#    rss_log.add("Made some change.")
#    rss_log.orphan("Deleting observation.")
#
#  *NOTE*: After an object is deleted, no one will ever be able to change that
#  RssLog again -- i.e. it is orphaned.
#
#  == Log Syntax
#
#  The log is kept in a variable-length text field, +notes+.  Each entry is
#  stored as a single line, with newest entries first.  Each line has time
#  stamp, localization string and any arguments required.  If the underlying
#  object is destroyed, the log becomes orphaned, and the object's last known
#  title string is stored at the very top of the log.
#
#  Here is an example of an Observation's log with five entries created by two
#  high-level actions: it is first created along with two images and a naming;
#  then it is destroyed, orphaning the log:
#
#    **__Russula%20chloroides__**%20Krbh.
#    20091214035011 log_observation_destroyed user douglas
#    20090722075919 log_image_created name 51164 user douglas
#    20090722075919 log_image_created name 51163 user douglas
#    20090722075919 log_consensus_changed
#      new **__Russula%20chloroides__**%20Krbh.
#      old **__Fungi%20sp.__**%20L.
#    20090722075918 log_observation_created user douglas
#
#  *NOTE*: All non-alphanumeric characters are escaped via private class
#  methods +escape+ and +unescape+.
#
#  *NOTE*: Somewhere in 2008/2009 we changed the syntax of the logs so we could
#  translate them.  We made the deliberate decision _not_ to convert all the
#  pre-existing logs.  Thus you will see various syntaxes prior to this
#  switchover.  These are processed specially in +parse_log+.
#
#  == Attributes
#
#  id::                 Locally unique numerical id, starting at 1.
#  updated_at::         Date/time it was last updated.
#  notes::              Log of changes.
#  location::           Owning Location (or nil).
#  name::               Owning Name (or nil).
#  observation::        Owning Observation (or nil).
#  project::            Owning Project (or nil).
#  species_list::       Owning SpeciesList (or nil).
#  glossary_term::      Owning GlossaryTerm (or nil).
#
#  == Class methods
#
#  all_types::          Object types with RssLog's (Array of Symbol's).
#
#  == Instance methods
#
#  add_with_date::      Same, but adds timestamp.
#  orphan::             About to delete object: add notes, clear association.
#  orphan_title::       Get old title from top line of orphaned log.
#  target::             Return owner object: Observation, Name, etc.
#  text_name::          Return title string of associated object.
#  format_name::        Return formatted title string of associated object.
#  unique_text_name::   (same, with id tacked on to make unique)
#  unique_format_name:: (same, with id tacked on to make unique)
#  url::                Return "show_blah/id" URL for associated object.
#  parse_log::          Parse log, see method for description of return value.
#  detail::             Figure out a message for most recent update.
#
#  == Callbacks
#
#  None.
#
################################################################################

class RssLog < AbstractModel
  belongs_to :location
  belongs_to :name
  belongs_to :observation
  belongs_to :project
  belongs_to :species_list
  belongs_to :glossary_term
  belongs_to :article

  # Override the default show_controller
  def self.show_controller
    "/observer"
  end

  # List of all object types that can have RssLog's.  (This is the order they
  # appear on the activity log page.)
  def self.all_types
    %w[observation name location species_list project glossary_term article]
  end

  # Returns the associated object, or nil if it's an orphan.
  def target
    location ||
      name ||
      observation ||
      project ||
      species_list ||
      glossary_term ||
      article
  end

  # Returns the associated object's id, or nil if it's an orphan.
  def target_id
    location_id ||
      name_id ||
      observation_id ||
      project_id ||
      species_list_id ||
      glossary_term_id ||
      article_id
  end

  # Return the type of object of the target, e.g., :observation
  # or nil if it's an orphan
  def target_type
    RssLog.all_types.each do |type|
      return type.to_sym if send("#{type}_id".to_sym)
    end
    nil
  end

  # Handy for prev/next handler.  Any object that responds to rss_log has an
  # attached RssLog.  In this case, it *is* the RssLog itself, meaning it is
  # an orphan log for a deleted object.
  def rss_log
    self
  end

  # The top line of log should be the old object's name after it is destroyed.
  def orphan_title
    name = notes.to_s.split("\n", 2).first
    if /^\d{14}/.match?(name)
      # This is an occasional error, when a log wasn't orphaned properly.
      _tag, args, _time = parse_log.first
      args[:this] || :rss_log_of_deleted_item.l
    else
      RssLog.unescape(name)
    end
  end

  # Returns plain text title of the associated object.
  def text_name
    if target
      if target.respond_to?(:real_text_name)
        target.real_text_name
      else
        target.text_name
      end
    else
      orphan_title.t.html_to_ascii.sub(/ (\d+)$/, "")
    end
  end

  # Returns plain text title of the associated object, with id tacked on.
  def unique_text_name
    if target
      target.unique_text_name
    else
      orphan_title.t.html_to_ascii
    end
  end

  # Returns formatted title of the associated object.
  def format_name
    if target
      target.format_name
    else
      orphan_title.sub(/ (\d+)$/, "")
    end
  end

  # Returns formatted title of the associated object, with id tacked on.
  def unique_format_name
    if target
      if target.respond_to?(:unique_format_name)
        target.unique_format_name
      else
        target.format_name + " (#{target_id || "?"})"
      end
    else
      orphan_title
    end
  end

  # Returns URL of <tt>show_#{object}</tt> action for the associated object.
  # That is, the RssLog for an Observation would return
  # <tt>"/observer/show_observation/#{id}"</tt>, and so on.  If the RssLog is
  # an orphan, it returns the generic <tt>"/observer/show_rss_log/#{id}"</tt>
  # URL.
  def url
    if location_id
      format("/location/show_location/%d?time=%d", location_id,
             updated_at.tv_sec)
    elsif name_id
      format("/name/show_name/%d?time=%d", name_id, updated_at.tv_sec)
    elsif observation_id
      format("/observer/show_observation/%d?time=%d", observation_id,
             updated_at.tv_sec)
    elsif project_id
      format("/project/show_project/%d?time=%d", project_id, updated_at.tv_sec)
    elsif species_list_id
      format("/observer/show_species_list/%d?time=%d", species_list_id,
             updated_at.tv_sec)
    elsif glossary_term_id
      format("/glossary_terms/%d?time=%d", glossary_term_id, updated_at.tv_sec)
    elsif article_id
      format("/articles/%d?time=%d", article_id, updated_at.tv_sec)
    else
      format("/observer/show_rss_log/%d?time=%d", id, updated_at.tv_sec)
    end
  end

  # Add entry to top of notes and save.  Pass in a localization key and a hash
  # of arguments it requires.  Changes +updated_at+ unless <tt>args[:touch]</tt>
  # is false.  (Changing +updated_at+ has the effect of pushing it to the front
  # of the RSS feed.)
  #
  #   name.rss_log.add(:log_name_updated,
  #     :user => user.login,
  #     :touch => false
  #   )
  #
  # *NOTE*: By default it includes these in args:
  #
  #   :user  => User.current    # Which user is responsible?
  #   :touch => true            # Bring to top of RSS feed?
  #   :time  => Time.now        # Timestamp to use.
  #   :save  => true            # Save changes?
  #
  def add_with_date(tag, args = {})
    entry = RssLog.encode(tag,
                          relevant_args(args),
                          args[:time] || Time.zone.now)
    RssLog.record_timestamps = false if args.key?(:touch) && !args[:touch]
    self.notes = entry + "\n" + notes.to_s
    # self.updated_at = args[:time] if args[:touch]
    save_without_our_callbacks unless args.key?(:save) && !args[:save]
    RssLog.record_timestamps = true
  end

  def relevant_args(args)
    result = {
      user: (User.current ? User.current.login : :UNKNOWN.l)
    }.update(args)
    result.delete(:touch)
    result.delete(:time)
    result.delete(:save)
    result
  end

  # Add line with timestamp and +title+ to notes, clear references to
  # associated object, and save.  Once this is done and the owner has been
  # deleted, this RssLog will be "orphaned" and will never change again.
  #
  #   obs.rss_log.orphan(observation.format_name, :log_observation_destroyed)
  #
  def orphan(title, key, args = {})
    args = args.merge(save: false)
    add_with_date(key, args)
    self.notes = RssLog.escape(title) + "\n" + notes.to_s
    save_without_our_callbacks
  end

  # Parse the log, returning a list of triplets, one for each line, newest
  # first:
  #
  #   for tag, args, time in rss_log.parse_log
  #     puts "#{time.web_time}: #{key.t(args)}"
  #   end
  #
  def parse_log(cutoff_time = nil)
    first = true
    results = []
    for line in notes.to_s.split("\n")
      if first && !line.match(/^\d{14}/)
        tag  = :log_orphan
        args = { title: self.class.unescape(line) }
        time = updated_at
      elsif line.present?
        tag, args, time = self.class.decode(line)
      end
      break if cutoff_time && time < cutoff_time

      results << [tag, args, time]
      first = false
    end
    results
  end

  def created_at
    begin
      tag, args, time = parse_log.last
    rescue StandardError
      []
    end
    time
  end

  # Figure out a message for most recent update.
  def detail
    begin
      tag, args, time = parse_log.first
    rescue StandardError
      []
    end
    if !target_type
      :rss_destroyed.t(type: :object)
    elsif !target_id ||
          tag.to_s.match?(/^log_#{target_type}_(merged|destroyed)/)
      :rss_destroyed.t(type: target_type)
    elsif !time || time < created_at + 1.minute
      :rss_created_at.t(type: target_type)
    else
      tag.t(args)
    end
  end

  ##############################################################################

  # Encode a line of the log.  Pass in a triplet:
  # tag:: Symbol
  # args:: Hash
  # time:: TimeWithZone
  def self.encode(tag, args, time)
    time = time.utc.strftime("%Y%m%d%H%M%S")
    tag = tag.to_s
    raise("Invalid rss log tag: #{tag}") if tag.blank?

    args = args.keys.sort_by(&:to_s).map do |key|
      [key.to_s, escape(args[key])]
    end.flatten
    [time, tag, *args].map do |x|
      # Make *absolutely* sure no logs are ever created with fields missing,
      # since this can royally f--- up the parser and crash things.
      x.blank? ? "." : x.gsub(/\s+/, "_")
    end.join(" ")
  end

  # Decode a line from the log.  Returns a triplet:
  # tag:: Symbol
  # args:: Hash
  # time:: TimeWithZone
  def self.decode(line)
    time, tag, *args = line.split
    odd = false
    args.map! do |x|
      odd = !odd
      odd ? x.to_sym : unescape(x)
    end
    args << "" if odd
    begin
      time = Time.parse(time).in_time_zone
    rescue StandardError => e
      # Caught this error in the log, not sure how/why.
      if Rails.env.production?
        time = Time.zone.now # (but don't crash in production)
      else
        raise("rss_log timestamp corrupt: time=#{time.inspect}, err=#{e}")
      end
    end
    [tag.to_s.to_sym, Hash[*args], time]
  end

  # Protect special characters (whitespace) in string for log encoder/decoder.
  def self.escape(str)
    str.to_s.gsub(/[%\s]/) { |m| "%%%02X" % m.ord }
  end

  # Reverse protection of special characters in string for log encoder/decoder.
  def self.unescape(str)
    str.to_s.gsub(/%(..)/) { Regexp.last_match(1).hex.chr }
  end
end
