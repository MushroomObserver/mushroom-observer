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

  def default_order
    "created_at"
  end
end
