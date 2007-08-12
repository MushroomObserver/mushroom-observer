class PastName < ActiveRecord::Base
  belongs_to :name
  belongs_to :user
  
  # Create a PastName from a Name.  Doesn't do any checks and doesn't save the PastName
  def self.make_past_name(name)
    past_name = PastName.new
    past_name.name = name
    past_name.created = name.created
    past_name.modified = name.modified
    past_name.user_id = name.user_id
    past_name.version = name.version
    past_name.observation_name = name.observation_name
    past_name.display_name = name.display_name
    
    past_name.rank = name.rank
    past_name.text_name = name.text_name
    past_name.author = name.author
    past_name.notes = name.notes
    past_name.deprecated = name.deprecated
    past_name.citation = name.citation
    past_name
  end
  
  # Map nil or false to ''
  def self.str_cmp(s1, s2)
    (s1 || '') != (s2 || '')
  end

  # Looks at the given name and compares it against what's in the database.
  # If a significant change has happened, then a PastName is created and saved.
  # The version number for the name is incremented as well.  Return true
  # if a PastName was created.
  def self.check_for_past_name(name)
    result = false
    if name.id
      old_name = Name.find(name.id)
      if (str_cmp(name.text_name, old_name.text_name) or
        str_cmp(name.author, old_name.author) or
        str_cmp(name.notes, old_name.notes) or
        (name.deprecated != old_name.deprecated) or
        str_cmp(name.citation, old_name.citation) or
        str_cmp(name.rank, old_name.rank))
        past_name = make_past_name(old_name)
        past_name.save
        name.version += 1
        result = true
      end
    end
    result
  end
  
  def status
    if self.deprecated
      "Deprecated"
    else
      "Valid"
    end
  end
end
