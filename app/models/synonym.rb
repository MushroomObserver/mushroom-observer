# encoding: utf-8
#
#  = Synonym Model
#
#  This model is used to group Names that have been synonymized.  All it does
#  is own two or more Names.  That's it.  Couldn't be easier.  Actually it's a
#  real mess, but all the complexity of merging synonyms, etc. is dealt with in
#  Name. 
#
#  *NOTE*: I have tweaked the code so that this class should _never_ be
#  instantiated.  Ever.  At all.  Really.  Well okay, except when creating it.
#
#  == Attributes
#
#  id::         Locally unique numerical id, starting at 1.
#  sync_id::    Globally unique alphanumeric id, used to sync with remote servers.
#
#  == Class methods
#
#  None.
#
#  == Instance methods
#
#  choose_accepted_name::  Sets "accepted_name" for all of the attached Name's.
#
#  == Callbacks
#
#  None.
#
################################################################################

class Synonym < AbstractModel
  has_many :names

  # Look through all the attached Name's and chooses one to be the official
  # "accepted" Name -- in practice, it just chooses the fist non-deprecated
  # name it comes across.  It doesn't matter which it chooses, so long as it is
  # unique and consistent. 
  # def choose_accepted_name
  #   accepted_name = names.first
  #   for name in names
  #     if not name.deprecated
  #       accepted_name = name
  #       break
  #     end
  #   end
  #   for name in names
  #     if name.accepted_name != accepted_name
  #       name.accepted_name = accepted_name
  #       name.save
  #     end
  #   end
  # end
end
