# frozen_string_literal: true

class Banner < ApplicationRecord
  validates :message, presence: true

  # Returns the latest active banner
  def self.current
    order(created_at: :desc).first
  end
end
