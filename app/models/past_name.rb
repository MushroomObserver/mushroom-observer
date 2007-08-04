class PastName < ActiveRecord::Base
  belongs_to :name
  belongs_to :user
  
  def self.make_past_name(name)
    past_name = PastName.new
    past_name.name = name
    past_name.created = name.created
    past_name.modified = name.modified
    past_name.user_id = name.user_id
    past_name.version = name.version
    past_name.rank = name.rank
    past_name.observation_name = name.observation_name
    past_name.display_name = name.display_name
    past_name.text_name = name.text_name
    past_name.author = name.author
    past_name.notes = name.notes
    past_name.deprecated = name.deprecated
    past_name.citation = name.citation
    past_name
  end
  
  def status
    if self.deprecated
      "Deprecated"
    else
      "Valid"
    end
  end
end
