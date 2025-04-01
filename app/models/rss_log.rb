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
#  List of models which log activity are presently:
#
#  * Article
#  * GlossaryTerm
#  * Location
#  * Name
#  * Observation
#  * Project
#  * SpeciesList
#
#  == Adding RssLog to Model
#
#  This might be out of date, but start with these steps:
#
#  1) Database: Add columns to rss_logs and new model tables via migration.
#
#       class AddRssLogToModel < ActiveRecord::Migration
#         def self.change
#           add_column(:rss_logs, :model_id, :integer)
#           add_column(:models, :rss_log_id, :integer)
#         end
#       end
#
#  2) New model: Create association, tell it which actions (if any) to
#     automatically log, provide standard title methods.  (Note that
#     AbstractModel will provide the +log+ method. The optional exclamation
#     points tell it to pop the object to the top of the Activity Log.)
#
#       belongs_to :rss_log
#       self.autolog_events = [:created!, :updated!, :destroyed!]
#       def text_name
#       def format_name
#       def unique_text_name
#       def unique_format_name
#
#  3) RssLog: Create association, add type to RssLog::ALL_TYPE_TAGS.
#
#       belongs_to :model
#       ALL_TYPE_TAGS # add "model"
#
#  4) View: Modify MatrixBoxPresenter if who/what/when/where are nonstandard.
#
#  5) Add "show log" link at bottom of model's show page:
#
#       <%= show_object_footer(@object) %>
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
#  pre-existing logs... But apparently at some later point we decided to convert
#  the old logs after all.  So, everything is now more or less correct.
#  Although, note that many orphaned logs point to nonexistent targets
#  (that is, target_id was never cleared), and still others (rare cases)
#  never had the target title added to the top of the log (and therefore the
#  log will claim it's not an orphan even though it is).  This latter is
#  definitely a bug or residue of unclean shutdown or something, but it's not
#  clear how to fix it.  Just be aware and write resilient code!
#
#  == Attributes
#
#  id::                 Locally unique numerical id, starting at 1.
#  created_at::         Date/time log or object was created.
#  updated_at::         Date/time it was last updated.
#  notes::              Log of changes.
#  name, name_id::      Owning Name (or nil).
#  etc.::               (Pair of methods for each type of model.)
#
#  == Class constants
#
#  ALL_TYPE_TAGS::          Object types with RssLog's (Array of Symbol's).
#
#  == Instance methods
#
#  add_with_date::      Same, but adds timestamp.
#  orphan::             About to delete object: add object title and notes.
#  orphan_title::       Get old title from top line of orphaned log.
#  orphan?::            Has rss_log been orphaned? (i.e., target destroyed?)
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
class RssLog < AbstractModel # rubocop:disable Metrics/ClassLength
  belongs_to :article
  belongs_to :glossary_term
  belongs_to :location
  belongs_to :name
  belongs_to :observation
  belongs_to :project
  belongs_to :species_list

  scope :order_by_default,
        -> { order_by(::Query::RssLogs.default_order) }

  scope :type, lambda { |types|
    return all if types.to_s == "all"

    types = types.to_s.split unless types.is_a?(Array)
    types &= ALL_TYPE_TAGS.map(&:to_s)
    return none if types.empty?

    types.map! { |type| arel_table[:"#{type}_id"].not_eq(nil) }
    where(or_clause(*types)).distinct
  }

  # Apply content filters to all types of RssLog requested in the current Query.
  # NOTE: One content filter may apply to two or more types (e.g. `:region`
  # applies to both Observations and Locations), so we need to build a query
  # where each type of RssLog is filtered separately.
  #
  # Query itself calls this scope because it has all the current query params,
  # and because Query::Filter knows what all the possible filter params are.
  # We probably wouldn't call this scope elsewhere, except from a test.
  #
  # For reference:
  # Query.new(:RssLog, region: "Canada", has_specimen: true).to_sql
  #
  # SELECT DISTINCT rss_logs.id
  # FROM `rss_logs`
  # LEFT OUTER JOIN `observations` ON rss_logs.observation_id = observations.id
  # LEFT OUTER JOIN `locations` ON rss_logs.location_id = locations.id
  # WHERE (observations.id IS NULL OR
  #        ((observations.specimen IS TRUE AND
  #          CONCAT(', ', observations.where) LIKE '%, Canada')))
  # AND (locations.id IS NULL OR
  #      (CONCAT(', ', locations.name) LIKE '%, Canada')))
  # ORDER BY rss_logs.updated_at DESC, rss_logs.id DESC
  #
  scope :content_filters, lambda { |params|
    return all if params.blank?

    scope = all
    # `type` here is a model
    filterable_types_in_current_query(params).each do |type|
      type_filters = active_filters_for_model(params, type)
      next if type_filters.blank?

      # Join association is singular for all RssLog associations
      association = type.name.underscore
      # Returns "logs that are not of this type, or if they are, then filtered"
      scope = scope.
              left_outer_joins(:"#{association}").
              where("#{association}_id": nil).distinct.
              or(RssLog.merge(filter_conditions_for_type(type, type_filters)))
    end
    scope
  }

  def self.filtering_statements(params)
    # `type` here is a model (var name `model` unavailable)
    filterable_types_in_current_query(params).map do |type|
      type_filters = active_filters_for_model(params, type)
      next if type_filters.blank?

      # Join association is singular for all RssLog associations
      association = type.name.underscore
      # Returns "logs that are not of this type, or if they are, then filtered"
      left_outer_joins(:"#{association}").
        where("#{association}_id": nil).distinct.
        or(RssLog.merge(filter_conditions_for_type(type, type_filters)))
    end
  end

  # Types requested in the current RssLog query that may have content filters
  # applied. Defaults to :all. Returns an array of model classes.
  def self.filterable_types_in_current_query(params)
    filterable_types = [:observation, :name, :location]
    active_types = case params[:type]
                   when nil, "", :all, "all"
                     filterable_types
                   when Array
                     params[:type]
                   when String
                     params[:type].split
                   end
    active_types.map { |type| type.to_s.camelize.constantize }
  end

  # Find any active filters relevant to a model, using Query::Filter.by_model.
  # Returns a hash of only the relevant params.
  def self.active_filters_for_model(params, model)
    ::Query::Filter.by_model(model).
      each_with_object({}) do |fltr, filter_params|
        next if (val = params[fltr.sym]).to_s == ""

        filter_params[fltr.sym] = val
      end
  end

  # Build a scope statement for one type (model).
  def self.filter_conditions_for_type(type, type_filters)
    # Condense all filters into an array of AR scope statements
    conditions_for_type = type_filters.reduce([]) do |conds, (k, v)|
      conds << type.send(k, v).distinct
    end
    # Join the array of conditions by `and`.
    and_clause(*conditions_for_type).distinct
  end

  # Maximum allowed length (in bytes) of notes column.  Actually it should be
  # 65535, I think, but let's mak sure there's a safe buffer.
  MAX_LENGTH = 65_500

  # List of all objects (Classes) that can have RssLogs.
  # (This is the order they appear on the activity log page.)
  ALL_TYPES = [
    Observation, Name, Location, SpeciesList, Project, GlossaryTerm, Article
  ].freeze

  # Returns Array of type_tags (Symbols) of ALL_TYPES.
  ALL_TYPE_TAGS = ALL_TYPES.map { |type| type.to_s.underscore.to_sym }.freeze

  # Returns the associated object, or nil if it's an orphan.
  def target
    ALL_TYPE_TAGS.each do |type|
      obj = send(type)
      return obj if obj
    end
    nil
  end

  # Returns the associated object's id, or nil if it's an orphan.
  def target_id
    ALL_TYPE_TAGS.each do |type|
      obj_id = send(:"#{type}_id")
      return obj_id if obj_id
    end
    nil
  end

  # Return the type of object of the target, e.g., :observation
  # or nil if it's an orphan
  def target_type
    ALL_TYPE_TAGS.each do |type|
      return type if send(:"#{type}_id")
    end
    nil
  end

  # Clear association with target.
  def clear_target_id
    ALL_TYPE_TAGS.each do |type|
      send(:"#{type}_id=", nil)
    end
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
      unescape(name)
    end
  end

  # Has target been destroyed (orphaning this log)?  Top line of log should be
  # the old object's name after it is destroyed.
  def orphan?
    !target_type || !notes.match?(/\A\d{14}/)
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
  # The time thing might have something to do with RSS log requirements?
  def url
    "#{(target || self).show_url}?time=#{updated_at.tv_sec}"
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
    entry = encode(tag, relevant_args(args), args[:time] || Time.zone.now)
    RssLog.record_timestamps = false if args.key?(:touch) && !args[:touch]
    add_entry(entry)
    save_without_our_callbacks unless args.key?(:save) && !args[:save]
    RssLog.record_timestamps = true
  end

  def relevant_args(args)
    { user: (User.current ? User.current.login : :UNKNOWN.l) }.
      update(args).except(:save, :time, :touch)
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
    add_entry(escape(title))
    clear_target_id
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
    results = []
    notes.to_s.split("\n").each do |line|
      if results.empty? && !line.match(/^\d{14}/)
        tag, args, time = decode_orphan_title(line)
      elsif line.present?
        tag, args, time = decode(line)
      else
        next
      end
      break if cutoff_time && time < cutoff_time

      results << [tag, args, time]
    end
    results
  end

  private

  def decode_orphan_title(line)
    [:log_orphan, { title: unescape(line) }, updated_at]
  end

  public

  # Figure out a message for most recent update.
  def detail
    log = parse_log
    if orphan?
      penultimate_message(log)
    elsif target_recently_created?(log)
      creation_message(log)
    else
      latest_message(log)
    end
  rescue StandardError => e
    Rails.env.production? ? raise(e) : ""
  end

  private

  def target_recently_created?(log)
    _latest_tag, _latest_args, latest_time = log.first
    first_time = created_at || log.last[2]
    latest_time && first_time && latest_time < first_time + 1.minute
  end

  def latest_message(log)
    tag, args = log.first
    tag.t(args)
  end

  def penultimate_message(log)
    tag, args = log[1]
    tag.present? ? tag.t(args) : :rss_destroyed.t(type: target_type)
  end

  def creation_message(log)
    if [:observation, :species_list].include?(target_type)
      :rss_created_at.t(type: target_type) # user would be redundant
    else
      # Creation should be first action logged.
      tag, args = log.last
      tag.t(args)
    end
  end

  ##############################################################################

  # Encode a line of the log.  Pass in a triplet:
  # tag:: Symbol
  # args:: Hash
  # time:: TimeWithZone
  def encode(tag, args, time)
    time = time.utc.strftime("%Y%m%d%H%M%S")
    tag = tag.to_s
    raise("Invalid rss log tag: #{tag}") if tag.blank?

    args = args.keys.sort_by(&:to_s).map do |key|
      [key.to_s, escape(args[key])]
    end.flatten
    [time, tag, *args].map { |x| remove_blanks(x) }.join(" ")
  end

  # Make *absolutely* sure no logs are ever created with fields missing,
  # since this can royally f--- up the parser and crash things.
  def remove_blanks(str)
    str.blank? ? "." : str.to_s.gsub(/\s+/, "_")
  end

  # Decode a line from the log.  Returns a triplet:
  # tag:: Symbol
  # args:: Hash
  # time:: TimeWithZone
  def decode(line)
    time, tag, *args = line.split
    [tag.to_s.to_sym, decode_args(args), decode_time(time)]
  end

  def decode_args(args)
    odd = false
    args.map! do |x|
      odd = !odd
      odd ? x.to_sym : unescape(x)
    end
    args << "" if odd
    Hash[*args]
  end

  def decode_time(str)
    Time.parse(str + "+0000").in_time_zone
  rescue StandardError
    Time.zone.now
  end

  # Protect special characters (whitespace) in string for log encoder/decoder.
  def escape(str)
    str.to_s.gsub(/[%\s]/) { |m| format("%%%<code>02X", code: m.ord) }
  end

  # Reverse protection of special characters in string for log encoder/decoder.
  def unescape(str)
    str.to_s.gsub(/%(..)/) { Regexp.last_match(1).hex.chr }
  end

  # Add line to top of notes field, truncating it to keep it within the MySQL
  # limit on TEXT field.
  def add_entry(entry)
    self.notes = "#{entry}\n#{notes}".truncate_bytes(MAX_LENGTH)
  end
end
