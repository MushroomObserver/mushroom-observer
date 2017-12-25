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

  # Mightly cronjob to ensure that no synonym records accidentally got deleted.
  # This actually happened to Fungi itself(!)  Not sure how it happened, and
  # obviously I'd prefer to fix the cause.  But meanwhile, might as well keep
  # the site working...
  def self.make_sure_all_referenced_synonyms_exist
    msgs = []
    references = Name.connection.select_values(%(
      SELECT DISTINCT synonym_id FROM names
      WHERE synonym_id IS NOT NULL
      ORDER BY synonym_id ASC
    ))
    records = Name.connection.select_values(%(
      SELECT id FROM synonyms ORDER BY id ASC
    ))
    unused  = records - references
    missing = references - records
    if unused.any?
      Name.connection.execute(%(
        DELETE FROM synonyms
        WHERE id IN (#{unused.map(&:to_s).join(",")})
      ))
      msgs << "Deleting #{unused.count} unused synonyms: #{unused.inspect}"
    end
    if missing.any?
      Name.connection.execute(%(
        INSERT INTO synonyms (id) VALUES
        #{missing.map { |id| "(#{id})" }.join(",")}
      ))
      msgs << "Restoring #{missing.count} missing synonyms: #{missing.inspect}"
    end
    msgs
  end
end
