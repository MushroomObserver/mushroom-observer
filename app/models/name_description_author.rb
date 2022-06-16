# frozen_string_literal: true

# Glue table between name_descriptions and users.
class NameDescriptionAuthor < ApplicationRecord
  belongs_to :name_description
  belongs_to :user
end
