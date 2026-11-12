# frozen_string_literal: true

require("test_helper")

class DonationTest < UnitTestCase
  def test_donor_list
    Donation.create!(amount: 50, who: "Anna Mosser", email: "a@example.com",
                     anonymous: false, reviewed: true, user: rolf)

    row = Donation.donor_list.find { |r| r["who"] == "Anna Mosser" }

    assert_not_nil(row, "donor_list should include a reviewed, " \
                        "non-anonymous donation")
    assert_equal(50, row["total"].to_i)
  end

  def test_donor_list_excludes_unreviewed_and_anonymous
    Donation.create!(amount: 10, who: "Unreviewed Donor",
                     email: "b@example.com", anonymous: false,
                     reviewed: false, user: rolf)
    Donation.create!(amount: 10, who: "Anonymous Donor",
                     email: "c@example.com", anonymous: true,
                     reviewed: true, user: rolf)

    names = Donation.donor_list.pluck("who")

    assert_not_includes(names, "Unreviewed Donor")
    assert_not_includes(names, "Anonymous Donor")
  end
end
