class Synonym < ActiveRecord::Base
  has_many(:names, :order => "search_name")
  has_one :rss_log
  
  def log(msg)
    if self.rss_log.nil?
      self.rss_log = RssLog.new
    end
    self.rss_log.addWithDate(msg, true)
  end
  
  def orphan_log(entry)
    self.log(entry) # Ensures that self.rss_log exists
    self.rss_log.species_list = nil
    self.rss_log.add(self.unique_text_name, false)
  end
  
  # Add name to self, but don't transfer existing synonyms
  def transfer(name)
    old_synonym_id = name.synonym_id
    if old_synonym_id != id
      touch = false
      name.synonym = self
      touch = true
      if not name.save
        raise "Unable to transfer %s" % name.display_name
      end
      self.modified = Time.now
      if old_synonym_id
        begin
          old_synonym = Synonym.find(old_synonym_id)
          if old_synonym.names.length > 1
            old_synonym.modified = Time.now
            old_synonym.save
          else # Cleanup useless synonym
            for old_syn in old_synonym.names
              old_syn.synonym = nil
              old_syn.save
            end
            old_synonym.destroy
          end
        rescue ActiveRecord::RecordNotFound
          # OK since name object may be stale
        end
      end
    end
  end
  
end
