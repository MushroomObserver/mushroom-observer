# frozen_string_literal: true

# Glue table between observations and herbarium_records.
class ObservationHerbariumRecord < ApplicationRecord
  belongs_to :observation
  belongs_to :herbarium_record
end
