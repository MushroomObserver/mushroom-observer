# frozen_string_literal: true

# Glue table between location_descriptions and user_groups.
class LocationDescriptionWriter < ApplicationRecord
  belongs_to :location_description
  belongs_to :user_group
end
