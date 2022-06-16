# frozen_string_literal: true

# Glue table between name_descriptions and users.
class NameDescriptionEditor < ApplicationRecord
  belongs_to :name_description
  belongs_to :user
end
