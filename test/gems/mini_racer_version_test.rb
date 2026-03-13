# frozen_string_literal: true

class MiniRacerVersionTest < FunctionalTestCase
  # test version "0.18.1" because ">= 0.19.0" will not compile for older Macs
  # Issue documented here: https://github.com/rubyjs/mini_racer/issues/359
  def test_mini_racer_version
    assert_equal(MiniRacer::VERSION, "0.18.1")
  end
end
