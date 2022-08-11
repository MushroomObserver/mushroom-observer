# frozen_string_literal: true

# Glue table between observations and collection_numbers.
class ObservationCollectionNumber < ApplicationRecord
  belongs_to :observation
  belongs_to :collection_number
end
