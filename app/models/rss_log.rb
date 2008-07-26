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
#    add(entry, touch?)         Add line to notes, and save it.
#    addWithDate(entry, touch?) Same, but adds timestamp.
#    orphan(title, entry)       About to delete object: add notes, clear association.
#    title                      Return title string of associated object.
#    url                        Return "show_blah/id" URL for associated object.
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

  # Add line to notes and save.  Changes +modified+ if +t+ is true.
  def add(entry, t)
    self.notes = sprintf("%s\n%s", entry, self.notes)
    if t
      touch
    else
      self.save
    end
  end

  # Add line with timestamp to notes and save.  Changes +modified+ if +t+ is true.
  def addWithDate(entry, t)
    add(sprintf("%s: %s", Time.now, entry), t)
  end

  # Add line with timestamp and +title+ to notes, clear references to
  # associated object, and save.  Once this is done and the owner has been
  # deleted, this RssLog will be "orphaned" and will never change again.
  def orphan(title, entry)
    self.observation = nil
    self.species_list = nil
    self.name = nil
    addWithDate(entry, false)
    add(title, false)
  end

  # Returns title of the associated object.  If this RssLog is an orphan, it
  # returns the first line of the notes (which is the old title from the
  # moment before the owner was deleted, see orphan method).
  def title
    result = ''
    observation = self.observation
    if observation
      result = observation.unique_text_name # Use the observation if present
    else
      species_list = self.species_list
      if species_list
        result = species_list.unique_text_name # else try the species_list
      else
        name = self.name
        if name
          result = name.search_name
        else
          notes = self.notes
          result = notes.split("\n")[0] unless notes.nil? # else use the first line of the text
        end
      end
    end
    result
  end

  # Returns URL of <tt>show_#{object}</tt> action for the associated object.
  # That is, the RssLog for an Observation would return <tt>"/observer/show_observation/#{id}"</tt>,
  # and so on.  If the RssLog is an orphan, it returns the generic <tt>"/observer/show_rss_log/#{id}"</tt> URL.
  def url
    result = sprintf("/observer/show_rss_log/%d?time=%d", self.id, self.modified.tv_sec)
    observation = self.observation
    if observation
      result = sprintf("/observer/show_observation/%d?time=%d", observation.id, self.modified.tv_sec)
    else
      species_list = self.species_list
      if species_list
        result = sprintf("/observer/show_species_list/%d?time=%d", species_list.id, self.modified.tv_sec)
      else
        name = self.name
        if name
          result = sprintf("/observer/show_name/%d?time=%d", name.id, self.modified.tv_sec)
        end
      end
    end
    result
  end
end
