# frozen_string_literal: true

require("test_helper")

# The observation a project puts forward for a name (#5416).
class Project::BestObservationTest < UnitTestCase
  def setup
    super
    @project = projects(:bolete_project)
    @name = names(:boletus_edulis)
    @user = users(:rolf)
  end

  def best
    Project::BestObservation.new(@project, @name).observation
  end

  # An observation of the name, in the project, with one image whose
  # vote is what the ranking is being asked about.
  def add_observation(image_vote:, confidence:, observed_on:, name: @name)
    observation = Observation.create!(
      user: @user, name: name, when: observed_on,
      where: "Burbank, California, USA", vote_cache: confidence
    )
    image = Image.create!(user: @user, when: observed_on,
                          content_type: "image/jpeg", vote_cache: image_vote)
    observation.images << image
    observation.update!(thumb_image_id: image.id)
    @project.observations << observation
    observation
  end

  def test_no_observation_of_that_name
    assert_nil(best)
  end

  # A photograph is what makes a scan worth the trouble, so the
  # best-voted one wins even when it is not the most recent.
  def test_the_best_voted_photograph_wins
    add_observation(image_vote: 2.0, confidence: 2.5,
                    observed_on: Date.parse("2026-09-01"))
    better = add_observation(image_vote: 4.0, confidence: 2.5,
                             observed_on: Date.parse("2024-09-01"))

    assert_equal(better, best)
  end

  def test_the_most_recent_breaks_a_tie
    add_observation(image_vote: 3.0, confidence: 2.5,
                    observed_on: Date.parse("2024-09-01"))
    newer = add_observation(image_vote: 3.0, confidence: 2.5,
                            observed_on: Date.parse("2026-09-01"))

    assert_equal(newer, best)
  end

  # Confidence is a gate, not part of the ranking: a doubted
  # observation gives way to a Promising one however good its photo.
  def test_a_doubted_observation_gives_way
    doubted = add_observation(image_vote: 4.0, confidence: 1.0,
                              observed_on: Date.parse("2026-09-01"))
    promising = add_observation(image_vote: 2.0, confidence: 2.0,
                                observed_on: Date.parse("2024-09-01"))

    assert_equal(promising, best)
    assert_not_equal(doubted, best)
  end

  # Nothing confident enough? Then whatever has a photograph.
  def test_falling_back_to_any_photograph
    doubted = add_observation(image_vote: 3.0, confidence: 1.0,
                              observed_on: Date.parse("2026-09-01"))

    assert_equal(doubted, best)
  end

  def test_falling_back_to_an_observation_with_no_photograph
    observation = Observation.create!(user: @user, name: @name,
                                      when: Date.parse("2026-09-01"),
                                      where: "Burbank, California, USA",
                                      vote_cache: 2.5)
    @project.observations << observation

    assert_equal(observation, best)
  end

  # An observation filed under a synonym is an observation of the
  # same taxon.
  def test_an_observation_under_a_synonym_counts
    synonym = names(:coprinus_comatus)
    synonym.update!(synonym: Synonym.create!)
    @name.update!(synonym_id: synonym.synonym_id)
    under_synonym = add_observation(image_vote: 3.0, confidence: 2.5,
                                    observed_on: Date.parse("2026-09-01"),
                                    name: synonym)

    assert_equal(under_synonym, best)
  end

  def test_an_observation_outside_the_project_does_not_count
    Observation.create!(user: @user, name: @name,
                        when: Date.parse("2026-09-01"),
                        where: "Burbank, California, USA", vote_cache: 2.5)

    assert_nil(best)
  end
end
