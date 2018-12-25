class Triple < ApplicationRecord
  def self.delete_predicate_matches(predicate)
    if valid_predicate(predicate)
      Triple.connection.delete %(
        DELETE FROM triples WHERE predicate = '#{predicate}'
      )
    end
  end

  private

  def self.valid_predicate(predicate)
    predicate.match(/^:\w+$/)
  end
end
