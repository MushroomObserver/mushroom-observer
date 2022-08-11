# frozen_string_literal: true

# Glue table between herbaria and users.
class HerbariumCurator < ApplicationRecord
  belongs_to :herbarium
  belongs_to :user
end
