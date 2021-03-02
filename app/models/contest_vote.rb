# frozen_string_literal: true

class ContestVote < ApplicationRecord
  belongs_to :contest_entry
  belongs_to :user
end
