#
#  This model handles the RSS feed.  Every object we care about gets one an
#  RssLog instance to report changes in that object.
#
#  1. has a timestamp
#  2. has notes
#  3. belongs an object
#
#  Right now there is a separate <tt>#{object}_id</tt> field for each kind
#  of object that can own an RssLog.  This should probably be changed to a
#  polymorphic association.  Possible owners are currently:
#
#  * Observation
#  * SpeciesList
#  * Name
#  * Synonym (hmmm, this doesn't seem to work...)
#
#  Usage:
#    rss_log = observation.rss_log
#    rss_log.add("Made some change.")
#    rss_log.orphan("Deleting observation.")
#
#  Note, after an object is deleted, no one will ever be able to change that
#  RssLog again -- i.e. it is orphaned.
#
#  Public Methods:
#    touch
#    add(key, args, touch?)     Add entry to notes, and save it.
#    add_with_date(key, args, touch?) Same, but adds timestamp.
#    orphan(title, entry)       About to delete object: add notes, clear association.
#    text_name                  Return title string of associated object.
#    format_name                Return formatted title string of associated object.
#    url                        Return "show_blah/id" URL for associated object.
#    parse_log                  Parse log, see method for description of return value.
#
################################################################################

class RssLog < ActiveRecord::Base

  belongs_to :observation
  belongs_to :species_list
  belongs_to :name

  # Set +modified+ to now and save.
  def touch
    self.modified = Time.now
    self.save
  end

  # Add entry to top of notes and save.  Changes +modified+ if +t+ is true.
  # Pass in a localization key and a hash of arguments it requires.
  def add(key, args={}, t=false)
    entry = RssLog.escape(key)
    entry += '(' + args.keys.sort_by {|x| x.to_s}.map do |k|
      RssLog.escape(k) + '=' + RssLog.escape(args[k])
    end.join(',') + ')'
    self.notes = entry + "\n" + self.notes.to_s
    if t
      self.touch
    else
      self.save
    end
  end

  # Add entry with timestamp to top of notes and save.  Changes +modified+ if +t+
  # is true.  Pass in a localization key and a hash of arguments it requires.
  def add_with_date(key, args=nil, t=false)
    add(key, args, false)
    self.notes = Time.now.to_s + ":" + self.notes.to_s
    if t
      self.touch
    else
      self.save
    end
  end

  # Add line with timestamp and +title+ to notes, clear references to
  # associated object, and save.  Once this is done and the owner has been
  # deleted, this RssLog will be "orphaned" and will never change again.
  def orphan(title, key, args=nil)
    self.observation  = nil
    self.species_list = nil
    self.name         = nil
    add_with_date(key, args, false)
    self.notes = RssLog.escape(title) + "\n" + self.notes.to_s
    self.save
  end

  # Returns the associated object, or nil if it's an orphan.
  def object
    self.observation || self.species_list || self.name
  end

  # Returns title of the associated object.  If this RssLog is an orphan, it
  # returns the first line of the notes (which is the old title from the
  # moment before the owner was deleted, see orphan method).
  def text_name
    result = ''
    if observation = self.observation
      result = observation.unique_text_name
    elsif species_list = self.species_list
      result = species_list.unique_text_name
    elsif name = self.name
      result = name.search_name
    else
      result = RssLog.unescape(self.notes.to_s.split("\n").first)
    end
    result
  end

  # Returns title of the associated object.  If this RssLog is an orphan, it
  # returns the first line of the notes (which is the old title from the
  # moment before the owner was deleted, see orphan method).
  def format_name
    result = ''
    if observation = self.observation
      result = observation.unique_format_name
    elsif species_list = self.species_list
      result = species_list.unique_format_name
    elsif name = self.name
      result = name.display_name
    else
      result = RssLog.unescape(self.notes.to_s.split("\n").first)
    end
    result
  end

  # Returns URL of <tt>show_#{object}</tt> action for the associated object.
  # That is, the RssLog for an Observation would return <tt>"/observer/show_observation/#{id}"</tt>,
  # and so on.  If the RssLog is an orphan, it returns the generic <tt>"/observer/show_rss_log/#{id}"</tt> URL.
  def url
    result = ''
    if observation = self.observation
      result = sprintf("/observer/show_observation/%d?time=%d", observation.id, self.modified.tv_sec)
    elsif species_list = self.species_list
      result = sprintf("/observer/show_species_list/%d?time=%d", species_list.id, self.modified.tv_sec)
    elsif name = self.name
      result = sprintf("/observer/show_name/%d?time=%d", name.id, self.modified.tv_sec)
    else
      result = sprintf("/observer/show_rss_log/%d?time=%d", self.id, self.modified.tv_sec)
    end
    result
  end

  # Parse the log, returning a list of triplets, one for each line, newest first:
  #   for line in rss_log.parse_log
  #     key, args, time = *line
  #     print key.t(args)
  #   end
  def parse_log
    first = true
    self.notes.split("\n").map do |str|
      key  = nil
      args = {}
      time = Time.gm(2000)

      # Strip timestamp off first.
      if str.match(/^(.*?\d\d\d\d): *(.*)/)
        time = Time.parse($1)
        str  = $2
      end

      # First entry of orphan log is title.
      if first && !self.object
        key  = :log_orphan
        args = { :title => RssLog.unescape(key) }

      # This is the "new" syntax: "key(arg=val,arg=val)"
      elsif str.match(/^([\w\%]+)\(([\w\%\=\,]*)\)$/)
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

      [key, args, time]
    end
  end

  # Protect special characters in string for log encoder/decoder.
  def self.escape(str)
    str.to_s.gsub(/\W/) { |x| '%%%02X' % x[0] }
  end

  # Reverse protection of special characters in string for log encoder/decoder.
  def self.unescape(str)
    str.to_s.gsub(/%(..)/) { $1.hex.chr }
  end
end
