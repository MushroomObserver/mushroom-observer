#
#  Simple container model to handle synonymy.  Properties:
#
#  1. owns two or more Name's
#
#  That's it.  Couldn't be easier.  Actually it's a real mess, but all the
#  complexity of merging synonyms, etc. is dealt with in Name.
#
#  Public Methods:
#    transfer(name)    Add given Name to this Synonym.
#
################################################################################

class Synonym < ActiveRecord::Base
  has_many(:names, :order => "search_name")

  # Add Name to self, but don't transfer that Name's synonyms.  Delete the
  # Name's old Synonym if there aren't any Names in it anymore.  Saves
  # everything *except* self.
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
