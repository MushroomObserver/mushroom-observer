# frozen_string_literal: true

# Donations to Mushroom Observer, Inc.
class Donation < ApplicationRecord
  require "arel-helpers"
  include ArelHelpers::ArelTable

  belongs_to :user

  def self.donor_list
    values = Donation.where(anonymous: 0, reviewed: 1).group(:who, :email).
             order(Donation[:amount].sum.desc,
                   Donation[:created_at].maximum.desc).
             pluck(:who, Donation[:amount].sum, Donation[:created_at].maximum)

    values.map do |who, total, most_recent|
      { "who" => who, "total" => total, "most_recent" => most_recent }
    end
  end

  def other_amount
    ""
  end
end
