# frozen_string_literal: true

class Banner < ApplicationRecord
  validates :message, presence: true

  # Returns the latest active banner
  def self.current
    order(created_at: :desc).first
  end

  # Each save is a new version; dismissal is remembered per version, so a
  # new one shows again to visitors who dismissed the last.
  def self.next_version
    (maximum(:version) || 0) + 1
  end
end
