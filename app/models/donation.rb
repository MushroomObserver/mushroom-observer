# frozen_string_literal: true

# Donations to Mushroom Observer, Inc.
class Donation < ApplicationRecord
  # Not an AbstractModel subclass -- that would also pull in RSS-log
  # autologging and user-contribution callbacks this financial record
  # has no use for. OrderingScopes is a self-contained concern (no
  # callbacks), so it's included directly to get `order_by` for
  # Query::Donations' sorting.
  include AbstractModel::OrderingScopes

  belongs_to :user

  scope :order_by_default, -> { order_by(::Query::Donations.default_order) }

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
