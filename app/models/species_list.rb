class SpeciesList < ActiveRecord::Base
  has_and_belongs_to_many :observations
  belongs_to :user
  has_one :rss_log

  def log(msg)
    if self.rss_log.nil?
      self.rss_log = RssLog.new
    end
    self.rss_log.addWithDate(msg)
  end
  
  def orphan_log(entry)
    self.log(entry) # Ensures that self.rss_log exists
    self.rss_log.species_list = nil
    self.rss_log.add(self.unique_name)
  end

  def species
    ''
  end
  
  def species=(list)
  end
  
  def unique_name
    title = self.title
    if title
      sprintf("%s (%d)", title[0..(MAX_FIELD_LENGTH-1)], self.id)
    else
      sprintf("Species List %d", self.id)
    end
  end
  
  def construct_observation(s, args)
    species_name = s.strip()
    if species_name != ''
      args["what"] = species_name
      if args["where"] == ''
        args["where"] = self.title
      end
      obs = Observation.new(args)
      obs.save
      self.observations << obs
    end
  end
  
  validates_presence_of :title
end
