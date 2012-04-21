require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class ConferenceEventTest < UnitTestCase
  def test_registration_count
    msa = conference_events(:msa_annual_meeting)
    assert_equal(4, msa.how_many)
  end
end
