# frozen_string_literal: true

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
#
#  == Class methods
#
#  Synonym.make_sure_all_refererenced_synonyms_exist::   Nightly cronjob.
#
#  == Instance methods
#
#  None.
#
#  == Callbacks
#
#  None.
#
class Synonym < AbstractModel
  has_many :names

  # Nightly cronjob to ensure that no synonym records accidentally got deleted.
  # This actually happened to Fungi itself(!)  Not sure how it happened, and
  # obviously I'd prefer to fix the cause.  But meanwhile, might as well keep
  # the site working...
  def self.make_sure_all_referenced_synonyms_exist
    msgs = []
    references = Name.select(:synonym_id).where.not(synonym: nil).distinct.
                 order(:synonym_id).pluck(:synonym_id)
    records = Synonym.all.order(id: :asc).pluck(:id)
    unused  = records - references
    missing = references - records
    if unused.any?
      Synonym.where(id: unused).delete_all
      msgs << "Deleting #{unused.count} unused synonyms: #{unused.inspect}"
    end
    if missing.any?
      insert_manager = arel_insert_all(missing)
      Name.connection.execute(insert_manager.to_sql)
      msgs << "Restoring #{missing.count} missing synonyms: #{missing.inspect}"
    end
    msgs
  end

  private_class_method def self.arel_insert_all(ids)
    table = Synonym.arel_table
    Arel::InsertManager.new.tap do |manager|
      manager.into(table)
      manager.columns << table[:id]
      manager.values = manager.create_values(ids, table[:id])
    end
  end
end
