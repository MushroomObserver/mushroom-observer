# frozen_string_literal: true

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
  require "arel-helpers"

  include ArelHelpers::ArelTable

  has_many :names

  # Nightly cronjob to ensure that no synonym records accidentally got deleted.
  # This actually happened to Fungi itself(!)  Not sure how it happened, and
  # obviously I'd prefer to fix the cause.  But meanwhile, might as well keep
  # the site working...
  def self.make_sure_all_referenced_synonyms_exist
    msgs = []
    # references = Name.connection.select_values(%(
    #   SELECT DISTINCT synonym_id FROM names
    #   WHERE synonym_id IS NOT NULL
    #   ORDER BY synonym_id ASC
    # ))
    # puts(references.join(",").to_s)
    reference_select = Name.select(:synonym_id).distinct.
                       where(Name[:synonym_id].not_eq(nil)).
                       order(Name[:synonym_id].asc)
    # puts(ref_selects.to_sql)
    references = Name.connection.select_values(reference_select.to_sql)
    # puts(references.join(",").to_s)

    # records = Name.connection.select_values(%(
    #   SELECT id FROM synonyms ORDER BY id ASC
    # ))
    record_select = Synonym.select(:id).order(Synonym[:id].asc)
    # puts(rec_selects.to_sql)
    records = Name.connection.select_values(record_select.to_sql)
    # puts(records.join(",").to_s)
    unused  = records - references
    missing = references - records
    # puts(unused.join(",").to_s)
    # puts(missing.join(",").to_s)

    if unused.any?
      # Name.connection.execute(%(
      #   DELETE FROM synonyms
      #   WHERE id IN (#{unused.map(&:to_s).join(",")})
      # ))
      delete_manager = Arel::DeleteManager.new.
                       from(Synonym.arel_table).
                       where(Synonym[:id].in(unused))
      # puts(delete_manager.to_sql)
      Name.connection.delete(delete_manager.to_sql)

      msgs << "Deleting #{unused.count} unused synonyms: #{unused.inspect}"
    end
    if missing.any?
      # Name.connection.execute(%(
      #   INSERT INTO synonyms (id) VALUES
      #   #{missing.map { |id| "(#{id})" }.join(",")}
      # ))

      insert_manager = Arel::InsertManager.new.tap do |manager|
        manager.into(Synonym.arel_table)
        manager.columns << Synonym[:id]
        manager.values = manager.create_values(missing, Synonym[:id])
      end
      # puts(insert_manager.to_sql)
      Name.connection.execute(insert_manager.to_sql)
      msgs << "Restoring #{missing.count} missing synonyms: #{missing.inspect}"
    end
    msgs
  end
end
