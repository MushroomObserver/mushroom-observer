# frozen_string_literal: true

# Donations to Mushroom Observer, Inc.
class Donation < ApplicationRecord
  require "arel-helpers"

  include ArelHelpers::ArelTable

  belongs_to :user

  # "SELECT who, SUM(amount) total, MAX(created_at) most_recent
  # FROM donations WHERE anonymous = 0 and reviewed = 1
  # GROUP BY who, email ORDER BY total DESC, most_recent DESC"
  def self.donor_list
    d = Donation.arel_table
    values = Donation.where(anonymous: 0, reviewed: 1).group(:who, :email).
             order(d[:amount].sum.desc, d[:created_at].maximum.desc).
             pluck(:who, d[:amount].sum, d[:created_at].maximum)

    values.map do |who, total, most_recent|
      { "who" => who, "total" => total, "most_recent" => most_recent }
    end
  end

  def other_amount
    ""
  end
end
