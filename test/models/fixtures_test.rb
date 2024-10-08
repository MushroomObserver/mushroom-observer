# frozen_string_literal: true

require "test_helper"

class FixturesTest < ActiveSupport::TestCase
  def test_observations_all_have_rss_logs
    Observation.find_each do |obs|
      name = ActiveRecord::FixtureSet.reverse_lookup(:observations, obs.id)
      assert_not_nil(
        obs.rss_log_id,
        "Observation #{name} needs a corresponding RssLog fixture."
      )
      assert_not_nil(
        obs.log_updated_at,
        "Observation #{name} needs a log_updated_at value."
      )
    end
  end
end
