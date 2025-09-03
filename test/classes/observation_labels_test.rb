# frozen_string_literal: true

require("test_helper")
require "prawn/measurement_extensions"

class ObservationLabelsTest < UnitTestCase
  def test_error_case
    new_root = Pathname.new("/tmp/fake_rails_root")
    Rails.stub(:root, new_root) do
      log_contents = with_captured_logger do
        obs = Observation.first
        doc = ObservationLabels.new(
          Query.lookup(:Observation, id_in_set: [obs.id])
        )
        doc.generate
      end
      assert_match(/Helvetica/, log_contents)
    end
  end
end
