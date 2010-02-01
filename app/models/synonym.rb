#
#  = Synonym Model
#
#  This model is used to group Names that have been synonymized.  All it does
#  is own two or more Names.  That's it.  Couldn't be easier.  Actually it's a
#  real mess, but all the complexity of merging synonyms, etc. is dealt with in
#  Name. 
#
#  == Attributes
#
#  id::         Locally unique numerical id, starting at 1.
#  sync_id::    Globally unique alphanumeric id, used to sync with remote servers.
#  created::    Date/time it was first created.
#  modified::   Date/time it was last modified.
#
#  == Class methods
#
#  None.
#
#  == Instance methods
#
#  names::      List of Names that belong to it.
#  transfer::   Transfer a Name from another Synonym into this Synonym.
#
#  == Callbacks
#
#  None.
#
################################################################################

class Synonym < AbstractModel
  has_many(:names, :order => "search_name")

  # Add Name to this Synonym, but don't transfer that Name's synonyms.  Delete
  # the Name's old Synonym if there aren't any Names in it anymore.  Everything
  # is saved.  (*NOTE*: this doesn't actually affect the Synonym record!) 
  #
  #   if correct_name.synonym
  #     correct_name.synonym.transfer(incorrect_name)
  #   else
  #     correct_name.synonym = Synonym.create
  #     correct_name.synonym.transfer(incorrect_name)
  #     correct_name.save
  #   end
  #
  def transfer(name)
    old_synonym_id = name.synonym_id
    if old_synonym_id != id
      touch = false
      name.synonym = self
      touch = true
      if not name.save
        raise :runtime_unable_to_transfer_name.t(:name => name.display_name)
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
