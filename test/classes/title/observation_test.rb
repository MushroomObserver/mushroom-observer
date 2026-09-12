# frozen_string_literal: true

require("test_helper")

class Title::ObservationTest < UnitTestCase
  def test_document_title
    obs = observations(:minimal_unknown_obs)

    assert_equal(obs.text_name, Title.for(obs).document_title)
  end

  # Observation has no page_title override -- the visible heading is
  # built separately by Views::Layouts::Header::ObjectTitle via
  # ConsensusNameLink, so Title::Observation only defines
  # document_title. Confirm page_title still falls through safely to
  # the base Title default rather than erroring.
  def test_page_title_falls_back_to_base_default
    obs = observations(:minimal_unknown_obs)

    assert_equal(:observation.ti, Title.for(obs).page_title)
  end
end
