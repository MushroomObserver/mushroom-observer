# frozen_string_literal: true

# Glue table between user_groups and users.
class UserGroupUser < ApplicationRecord
  belongs_to :user_group
  belongs_to :user
end
