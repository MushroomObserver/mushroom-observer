class RssLog < ActiveRecord::Base

  belongs_to :observation
  belongs_to :species_list
  belongs_to :name

  def touch
    self.modified = Time.now
    self.save
  end
  
  def add(entry, t)
    self.notes = sprintf("%s\n%s", entry, self.notes)
    if t
      touch
    end
  end
  
  def addWithDate(entry, t)
    add(sprintf("%s: %s", Time.now, entry), t)
  end
  
  def orphan(title, entry)
    self.observation = nil
    self.species_list = nil
    self.name = nil
    addWithDate(entry, false)
    add(title, false)
  end
        
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
