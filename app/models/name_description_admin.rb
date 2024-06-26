# frozen_string_literal: true

# Glue table between name_descriptions and user_groups.
class NameDescriptionAdmin < ApplicationRecord
  belongs_to :name_description
  belongs_to :user_group
end
