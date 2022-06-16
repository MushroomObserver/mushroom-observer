# frozen_string_literal: true

# Glue table between observations and images.
class ObservationImage < ApplicationRecord
  belongs_to :observation
  belongs_to :image
end
