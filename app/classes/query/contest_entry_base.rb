# frozen_string_literal: true

class Query::ContestEntryBase < Query::Base
  def model
    ContestEntry
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time]
    )
  end
end
