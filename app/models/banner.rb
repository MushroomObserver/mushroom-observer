# frozen_string_literal: true

class Banner < ApplicationRecord
  validates :message, presence: true

  # Returns the latest active banner
  def self.current
    order(created_at: :desc).first
  end

  def test_version
    format("Style/RedundantFormat offense added in RuboCop 1.72")
    /#{%w[Lint ArrayLiteralInRegexp added in RuboCop 1.72]}/
  end
end
