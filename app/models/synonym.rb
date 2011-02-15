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
#  None.
#
#  == Callbacks
#
#  None.
#
################################################################################

class Synonym < AbstractModel
  has_many :names
end
