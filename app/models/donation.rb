# frozen_string_literal: true
# Donations to Mushroom Observer, Inc.
class Donation < ApplicationRecord
  belongs_to :user

  def self.donor_list
    connection.select_all(
      "SELECT who, SUM(amount) total, MAX(created_at) most_recent
      FROM donations WHERE anonymous = 0 and reviewed = 1
      GROUP BY who, email ORDER BY total DESC, most_recent DESC"
    ).to_a
  end

  def other_amount
    ""
  end
end
