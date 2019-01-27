# frozen_string_literal: true
class Triple < ApplicationRecord
  def self.delete_predicate_matches(predicate)
    return unless valid_predicate(predicate)

    Triple.connection.delete(conditions: ["predicate = ?", predicate])
  end

  def self.valid_predicate(predicate)
    predicate.match(/^:\w+$/)
  end
  private_class_method :valid_predicate
end
