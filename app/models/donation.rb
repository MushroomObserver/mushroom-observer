# frozen_string_literal: true

# Donations to Mushroom Observer, Inc.
class Donation < ApplicationRecord
  belongs_to :user

  def self.donor_list
    select_manager = arel_select_donor_list
    # puts(select_manager.to_sql)
    Donation.connection.select_all(select_manager.to_sql).to_a
  end

  # rubocop:disable Metrics/AbcSize
  # "SELECT who, SUM(amount) total, MAX(created_at) most_recent
  # FROM donations WHERE anonymous = 0 and reviewed = 1
  # GROUP BY who, email ORDER BY total DESC, most_recent DESC"
  private_class_method def self.arel_select_donor_list
    d = Donation.arel_table
    d.where(d[:anonymous].eq(0).and(d[:reviewed].eq(1))).
      project(d[:who], d[:amount].sum, d[:created_at].maximum).
      group(d[:who], d[:email]).
      order(d[:amount].sum.desc, d[:created_at].maximum.desc)
  end
  # rubocop:enable Metrics/AbcSize

  def other_amount
    ""
  end
end
