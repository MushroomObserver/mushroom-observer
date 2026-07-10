# frozen_string_literal: true

require("test_helper")

# CheckRssLogsJob is an abstract base -- never scheduled directly (see
# config/recurring.yml). CheckObservationRssLogsJob and
# CheckOtherRssLogsJob (their own test files) cover the actual repair
# behavior; this just guards the abstract-method contract subclasses
# must implement.
class CheckRssLogsJobTest < ActiveJob::TestCase
  def test_check_types_raises_for_the_abstract_base
    assert_raises(NotImplementedError) do
      CheckRssLogsJob.new.send(:check_types)
    end
  end

  def test_check_ghosts_defaults_to_false
    assert_not(CheckRssLogsJob.new.send(:check_ghosts?))
  end
end
