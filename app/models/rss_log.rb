#
#  = RSS Log Model
#
#  This model handles the RSS feed.  Every object we care about gets an RssLog
#  instance to report changes in that object.  Going forward, every new object
#  gets assigned one; historically, there are loads of objects without, but we
#  don't really care, so they stay that way until they are modified. 
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
#  * SpeciesList
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
#    **__Russula chloroides__** Krbh.
#    20091214035011:log_observation_destroyed(user=douglas)
#    20090722075919:log_image_created(name=51164,user=douglas)
#    20090722075919:log_image_created(name=51163,user=douglas)
#    20090722075919:log_consensus_changed(new=**__Russula chloroides__** Krbh.,old=**__Fungi sp.__** L.)
#    20090722075918:log_observation_created(user=douglas)
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
#  modified::           Date/time it was last modified.
#  notes::              Log of changes.
#  location::           Owning Location (or nil).
#  name::               Owning Name (or nil).
#  observation::        Owning Observation (or nil).
#  species_list::       Owning SpeciesList (or nil).
#
#  == Class methods
#
#  None.
#
#  == Instance methods
#
#  add_with_date        Same, but adds timestamp.
#  orphan               About to delete object: add notes, clear association.
#  orphan_title         Get old title from top line of orphaned log.
#  object               Return owner object: Observation, Name, etc.
#  text_name            Return title string of associated object.
#  format_name          Return formatted title string of associated object.
#  unique_text_name     (same, with id tacked on to make unique)
#  unique_format_name   (same, with id tacked on to make unique)
#  url                  Return "show_blah/id" URL for associated object.
#  parse_log            Parse log, see method for description of return value.
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
  belongs_to :species_list

  # Add entry to top of notes and save.  Pass in a localization key and a hash
  # of arguments it requires.  Changes +modified+ unless <tt>args[:touch]</tt>
  # is false.  (Changing +modified+ has the effect of pushing it to the front
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
  def add_with_date(key, args={})
    args = {
      :user  => (User.current ? User.current.login : :UNKNOWN.l),
      :touch => true,
      :time  => Time.now,
      :save  => true,
    }.merge(args)

    key2 = RssLog.escape(key)

    args2 = args.keys.sort_by(&:to_s) - [:touch, :time, :save]
    args2 = args2.map do |k|
      RssLog.escape(k) + '=' + RssLog.escape(args[k])
    end.join(',')

    entry = "#{args[:time]}:#{key2}(#{args2})"

    self.notes = entry + "\n" + notes.to_s
    self.modified = args[:time] if args[:touch]
    self.save_without_our_callbacks if args[:save]
  end

  # Add line with timestamp and +title+ to notes, clear references to
  # associated object, and save.  Once this is done and the owner has been
  # deleted, this RssLog will be "orphaned" and will never change again.
  #
  #   obs.rss_log.orphan(observation.format_name, :log_observation_destroyed)
  #
  def orphan(title, key, args={})
    args = args.merge(:save => false)
    add_with_date(key, args)
    self.notes = RssLog.escape(title) + "\n" + self.notes.to_s
    self.location     = nil
    self.name         = nil
    self.observation  = nil
    self.species_list = nil
    self.save_without_our_callbacks
  end

  # Returns the associated object, or nil if it's an orphan.
  def object
    location || name || observation || species_list
  end

  # Get title from top line of orphaned log.  (Should be the +format_name+.)
  def orphan_title
    RssLog.unescape(notes.to_s.split("\n").first)
  end

  # Handy for prev/next handler.  Any object that responds to rss_log has an
  # attached RssLog.  In this case, it *is* the RssLog itself, meaning it is
  # an orphan log for a deleted object.
  def rss_log
    self
  end

  # Returns plain text title of the associated object.
  def text_name
    if object
      object.text_name
    else
      orphan_title.t.html_to_ascii.sub(/ (\d+)$/, '')
    end
  end

  # Returns plain text title of the associated object, with id tacked on.
  def unique_text_name
    if object
      object.unique_text_name
    else
      orphan_title.t.html_to_ascii
    end
  end

  # Returns formatted title of the associated object.
  def format_name
    if object
      object.format_name
    else
      orphan_title.sub(/ (\d+)$/, '')
    end
  end

  # Returns formatted title of the associated object, with id tacked on.
  def unique_format_name
    if object
      object.unique_format_name
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
    result = ''
    if location_id
      result = sprintf("/location/show_location/%d?time=%d", location_id, self.modified.tv_sec)
    elsif name_id
      result = sprintf("/name/show_name/%d?time=%d", name_id, self.modified.tv_sec)
    elsif observation_id
      result = sprintf("/observer/show_observation/%d?time=%d", observation_id, self.modified.tv_sec)
    elsif species_list_id
      result = sprintf("/observer/show_species_list/%d?time=%d", species_list_id, self.modified.tv_sec)
    else
      result = sprintf("/observer/show_rss_log/%d?time=%d", id, self.modified.tv_sec)
    end
    result
  end

  # Parse the log, returning a list of triplets, one for each line, newest first:
  #
  #   for line in rss_log.parse_log
  #     key, args, time = *line
  #     puts "#{time}: #{key.t(args)}"
  #   end
  #
  # NOTE: This is pretty slow.  It accounts for most of the time it takes to
  # serve the RSS feed (/observer/rss).  I'm not sure how to improve it...
  #
  def parse_log(cutoff_time=nil)
    first = true
    results = []
    for str in notes.split("\n")
      key  = nil
      args = {}
      time = Time.gm(2000)

      # Strip timestamp off first.
      if str.match(/^(.*?\d\d\d\d): *(.*)/)
        time = Time.parse($1)
        str  = $2
      end

      # Let caller request only recent logs.
      break if cutoff_time && time < cutoff_time

      # First entry of orphan log is title.
      if first && !self.object_id
        key   = :log_orphan
        args  = { :title => RssLog.unescape(key) }
        first = false

      # This is the "new" syntax: "key(arg=val,arg=val)"
      elsif str.match(/^([\w\%]+)\((.*)\)$/)
        key = $1
        for keyval in $2.split(',')
          if keyval.match(/=/)
            k = $`
            v = $'
            k = RssLog.unescape(k).to_sym
            v = RssLog.unescape(v)
            args[k] = v
          end
        end
        key = RssLog.unescape(key).to_sym

      # These are the old log messages.
      elsif str.match(/^Approved by (.*?)\.?$/);                          key = :log_approved_by;            args = { :user => $1 }
      elsif str.match(/^Comment added by (.*?): (.*?)\.?$/);              key = :log_comment_added;          args = { :user => $1, :summary => $2 }
      elsif str.match(/^Comment destroyed by (.*?): (.*?)\.?$/);          key = :log_comment_destroyed;      args = { :user => $1, :summary => $2 }
      elsif str.match(/^Comment updated by (.*?): (.*?)\.?$/);            key = :log_comment_updated;        args = { :user => $1, :summary => $2 }
      elsif str.match(/^Consensus established: (.*?)\.?$/);               key = :log_consensus_reached;      args = { :name => $1 }
      elsif str.match(/^Consensus rejected (.*?) in favor of (.*?)\.?$/); key = :log_consensus_changed;      args = { :old => $1, :new => $2 }
      elsif str.match(/^Deprecated by (.*?)\.?$/);                        key = :log_deprecated_by;          args = { :user => $1 }
      elsif str.match(/^Deprecated in favor of (.*?) by (.*?)\.?$/);      key = :log_name_deprecated;        args = { :user => $2, :other => $1 }
      elsif str.match(/^Image created by (.*?): (.*?)\.?$/);              key = :log_image_created;          args = { :user => $1, :name => $2 }
      elsif str.match(/^Image destroyed by (.*?): (.*?)\.?$/);            key = :log_image_destroyed;        args = { :user => $1, :name => $2 }
      elsif str.match(/^Image removed by (.*?): (.*?)\.?$/);              key = :log_image_removed;          args = { :user => $1, :name => $2 }
      elsif str.match(/^Image removed (.*?)\.?$/);                        key = :log_image_removed;          args = { :user => '', :name => $1 }
      elsif str.match(/^Image reused by (.*?): (.*?)\.?$/);               key = :log_image_reused;           args = { :user => $1, :name => $2 }
      elsif str.match(/^Name deprecated by (.*?)\.?$/);                   key = :log_deprecated_by;          args = { :user => $1 }
      elsif str.match(/^Name merged with (.*?)\.?$/);                     key = :log_name_merged;            args = { :name => $1 }
      elsif str.match(/^Name updated by (.*?)\.?$/);                      key = :log_name_updated;           args = { :user => $1 }
      elsif str.match(/^Naming changed by (.*?): (.*?)\.?$/);             key = :log_naming_updated;         args = { :user => $1, :name => $2 }
      elsif str.match(/^Naming created by (.*?): (.*?)\.?$/);             key = :log_naming_created;         args = { :user => $1, :name => $2 }
      elsif str.match(/^Naming deleted by (.*?): (.*?)\.?$/);             key = :log_naming_destroyed;       args = { :user => $1, :name => $2 }
      elsif str.match(/^Observation created by (.*?)\.?$/);               key = :log_observation_created;    args = { :user => $1 }
      elsif str.match(/^Observation destroyed by (.*?)\.?$/);             key = :log_observation_destroyed;  args = { :user => $1 }
      elsif str.match(/^Observation updated by (.*?)\.?$/);               key = :log_observation_updated;    args = { :user => $1 }
      elsif str.match(/^Preferred over (.*?) by (.*?)\.?$/);              key = :log_name_approved;          args = { :user => $2, :other => $1 }
      elsif str.match(/^Species list created by (.*?)\.?$/);              key = :log_species_list_created;   args = { :user => $1 }
      elsif str.match(/^Species list destroyed by (.*?)\.?$/);            key = :log_species_list_destroyed; args = { :user => $1 }
      elsif str.match(/^Species list updated by (.*?)\.?$/);              key = :log_species_list_updated;   args = { :user => $1 }
      elsif str.match(/^Updated by (.*?)\.?$/);                           key = :log_updated_by;             args = { :user => $1 }
      elsif str.match(/^Comment, (.*?), added by (.*?)\.?$/);             key = :log_comment_added;          args = { :user => $2, :summary => $1 }
      elsif str.match(/^Comment, (.*?), updated by (.*?)\.?$/);           key = :log_comment_updated;        args = { :user => $2, :summary => $1 }
      elsif str.match(/^Comment, (.*?), destroyed by (.*?)\.?$/);         key = :log_comment_destroyed;      args = { :user => $2, :summary => $1 }
      elsif str.match(/^Image, (.*?), created by (.*?)\.?$/);             key = :log_image_created;          args = { :user => $2, :name => $1 }
      elsif str.match(/^Image, (.*?), destroyed by (.*?)\.?$/);           key = :log_image_destroyed;        args = { :user => $2, :name => $1 }
      elsif str.match(/^Image, (.*?), removed by (.*?)\.?$/);             key = :log_image_removed;          args = { :user => $2, :name => $1 }
      elsif str.match(/^Image, (.*?), updated by (.*?)\.?$/);             key = :log_image_updated;          args = { :user => $2, :name => $1 }
      elsif str.match(/^Image, (.*?), reused by (.*?)\.?$/);              key = :log_image_reused;           args = { :user => $2, :name => $1 }
      elsif str.match(/^Observation, (.*?), destroyed by (.*?)\.?$/);     key = :log_observation_destroyed2; args = { :user => $2, :name => $1 }
      elsif str.match(/^(.*?) merged with (.*?)\.?$/);                    key = :log_name_merged;            args = { :name => $2 }
      else
        key = :log_ancient
        args = { :string => str }
      end

      results << [key, args, time]
    end
    return results
  end

################################################################################

private

  # Protect special characters in string for log encoder/decoder.
  def self.escape(str)
    str.to_s.gsub(/\W/) { '%%%02X' % $&[0] }
  end

  # Reverse protection of special characters in string for log encoder/decoder.
  def self.unescape(str)
    str.to_s.gsub(/%(..)/) { $1.hex.chr }
  end
end
