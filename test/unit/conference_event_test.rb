require 'test_helper'

class ConferenceEventTest < ActiveSupport::TestCase
  test "test_registration_count" do
    msa = conference_events(:msa_annual_meeting)
    assert_equal(4, msa.how_many)
  end
end
