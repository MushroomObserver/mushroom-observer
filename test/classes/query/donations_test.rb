# frozen_string_literal: true

require("test_helper")
require("query_extensions")

class Query::DonationsTest < UnitTestCase
  include QueryExtensions

  def test_donation_all
    expects = Donation.order_by_default
    assert_query(expects, :Donation)
  end

  def test_donation_order_by_amount
    expects = Donation.order_by(:amount)
    assert_query(expects, :Donation, order_by: :amount)
  end

  def test_donation_order_by_who
    expects = Donation.order_by(:who)
    assert_query(expects, :Donation, order_by: :who)
  end

  def test_donation_order_by_created_at
    expects = Donation.order_by(:created_at)
    assert_query(expects, :Donation, order_by: :created_at)
  end

  def test_donation_order_by_updated_at
    expects = Donation.order_by(:updated_at)
    assert_query(expects, :Donation, order_by: :updated_at)
  end
end
