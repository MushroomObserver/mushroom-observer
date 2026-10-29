# frozen_string_literal: true

require("test_helper")

# Unit tests for the confidence weight Inat::MoObservationBuilder assigns to
# an import's single consensus naming (#4212). The integration coverage in
# test/jobs/inat_import_job_test.rb exercises the sequence / research /
# non-research branches against recorded fixtures; this isolates naming_vote
# so every branch is pinned — including "provisional name without a sequence",
# which no real iNat fixture can produce (a prov name implies a sequence).
class InatMoObservationBuilderTest < UnitTestCase
  # Minimal stand-in for an ::Inat::Obs, exposing only the fields/methods
  # MoObservationBuilder reads in these unit tests.
  class FakeInatObs
    FAKE_INAT_ID = 12_345_678
    def initialize(sequences:, provisional_name:, quality_grade:,
                   name_override: nil, obs_taxon_name: nil)
      @sequences = sequences
      @provisional_name = provisional_name
      @quality_grade = quality_grade
      @name_override = name_override
      @obs_taxon_name = obs_taxon_name
    end

    attr_reader :sequences, :provisional_name, :name_override

    def name
      @obs_taxon_name
    end

    def [](key)
      { quality_grade: @quality_grade, license_code: "cc-by",
        identifications: [], id: FAKE_INAT_ID }[key]
    end
  end

  # DNA evidence is the strongest signal: max vote regardless of grade or
  # whether there's a provisional name.
  def test_naming_vote_sequence_wins
    assert_equal(Vote::MAXIMUM_VOTE,
                 naming_vote(sequence: true, provisional: false,
                             quality_grade: "casual"))
    assert_equal(Vote::MAXIMUM_VOTE,
                 naming_vote(sequence: true, provisional: true,
                             quality_grade: "needs_id"))
  end

  # A provisional name (no sequence) is Promising — the branch the recorded
  # fixtures can't cover.
  def test_naming_vote_provisional_without_sequence_is_promising
    assert_equal(Vote::NEXT_BEST_VOTE,
                 naming_vote(sequence: false, provisional: true,
                             quality_grade: "needs_id"))
  end

  def test_naming_vote_unparseable_provisional_is_no_evidence
    fake = FakeInatObs.new(sequences: [], provisional_name: "-",
                           quality_grade: "needs_id")
    builder = Inat::MoObservationBuilder.new(
      inat_obs: fake, user: users(:rolf), external_site: :stub
    )

    assert_equal(naming_vote(sequence: false, provisional: false,
                             quality_grade: "needs_id"),
                 builder.send(:naming_vote),
                 "An unparseable provisional name should not raise the vote")
  end

  def test_naming_vote_research_grade_is_promising
    assert_equal(Vote::NEXT_BEST_VOTE,
                 naming_vote(sequence: false, provisional: false,
                             quality_grade: "research"))
  end

  def test_naming_vote_non_research_is_could_be
    assert_equal(Vote::MIN_POS_VOTE,
                 naming_vote(sequence: false, provisional: false,
                             quality_grade: "needs_id"))
    assert_equal(Vote::MIN_POS_VOTE,
                 naming_vote(sequence: false, provisional: false,
                             quality_grade: "casual"))
  end

  # When the iNat provisional name already exists in MO, reuse it rather than
  # posting a new one.
  def test_prov_name_reuses_existing_mo_name
    existing = names(:lactarius_alpinus)
    builder = builder_for(provisional_name: existing.text_name)
    assert_equal(existing, builder.send(:prov_name))
  end

  # An override matching an existing MO name reuses it (no API post).
  def test_override_name_reuses_existing_mo_name
    existing = names(:coprinus_comatus)
    builder = builder_for(name_override: existing.text_name)
    assert_equal(existing, builder.send(:override_name))
  end

  # An unparseable override falls back to nil so the import proceeds with the
  # provisional/Community lead.
  def test_override_name_unparseable_falls_back_to_nil
    assert_nil(builder_for(name_override: "see comments").send(:override_name))
  end

  # A failure while resolving the override (e.g. an API error) is logged and
  # falls back to nil rather than aborting the import.
  def test_override_name_falls_back_when_resolution_raises
    builder = builder_for(name_override: "Boletus edulis")
    builder.define_singleton_method(:find_or_create_name) { |_| raise("boom") }

    # Capture the rescue's Rails.logger.warn call instead of letting it
    # through -- the test logger writes to $stdout, so the deliberate
    # "boom" otherwise dumps into the suite's console output looking
    # like a failure elsewhere.
    logged = nil
    Rails.logger.stub(:warn, ->(msg) { logged = msg }) do
      assert_nil(builder.send(:override_name))
    end
    assert_includes(logged, "boom")
  end

  # No override field => no override name.
  def test_override_name_absent_is_nil
    assert_nil(builder_for.send(:override_name))
  end

  # The override naming carries the override reason text.
  def test_override_naming_reason
    existing = names(:coprinus_comatus)
    builder = builder_for(name_override: existing.text_name)
    assert_equal("Following Species Name Override from iNat",
                 builder.send(:used_references_explanation, existing))
  end

  # The leading ID explanation links to the iNat observation and
  # uses the inat_leading_id translation string plus today's date.
  def test_observation_taxon_naming_reason
    name = names(:peltigera)
    id = FakeInatObs::FAKE_INAT_ID
    inat_link = "<a href=\"#{Inat::Constants::SITE}/observations/#{id}\">" \
                "iNat #{id}</a>"
    expected = "#{inat_link}, #{:inat_leading_id.l} " \
               "#{Time.zone.today.strftime("%Y-%m-%d")}"
    assert_equal(expected,
                 builder_for(obs_taxon_name: name).
                   send(:used_references_explanation, name),
                 "Observation taxon explanation should link to iNat " \
                 "observation and include date")
  end

  # When the obs taxon is a misspelling and the proposed name is its correct
  # spelling, the observation taxon explanation appends the corrected spelling
  # note.
  def test_observation_taxon_naming_reason_corrected_spelling
    misspelling = names(:petigera)
    correct = misspelling.correct_spelling
    assert(correct, "Test requires a name fixture with correct_spelling set")
    id = FakeInatObs::FAKE_INAT_ID
    inat_link = "<a href=\"#{Inat::Constants::SITE}/observations/#{id}\">" \
                "iNat #{id}</a>"
    expected = "#{inat_link}, #{:inat_leading_id.l} " \
               "#{Time.zone.today.strftime("%Y-%m-%d")} " \
               "#{:inat_corrected_spelling.l}"
    assert_equal(expected,
                 builder_for(obs_taxon_name: misspelling).
                   send(:used_references_explanation, correct),
                 "Observation taxon explanation should append corrected " \
                 "spelling note when proposed name corrects the obs taxon")
  end

  # Re-importing (or re-running the builder) reuses the namer's existing
  # naming instead of stacking a duplicate, updating the vote in place
  # (#5186).
  def test_add_naming_with_vote_reuses_the_namers_naming
    obs = observations(:minimal_unknown_obs)
    obs.namings.to_a.each do |n|
      n.current_user = users(:rolf)
      n.destroy
    end
    name = names(:coprinus_comatus)
    namer = users(:rolf)
    builder = builder_for
    builder.instance_variable_set(:@observation, obs)
    builder.define_singleton_method(:used_references_explanation) { |_| "ref" }

    assert_difference("Naming.count", 1) do
      builder.send(:add_naming_with_vote, name:, namer:,
                                          value: Vote::MAXIMUM_VOTE)
    end
    assert_no_difference("Naming.count") do
      builder.send(:add_naming_with_vote, name:, namer:,
                                          value: Vote::MINIMUM_VOTE)
    end

    naming = obs.reload.namings.find_by(user: namer, name:)
    assert_equal(Vote::MINIMUM_VOTE, naming.votes.find_by(user: namer).value,
                 "the second import updates the vote in place")
  end

  private

  def builder_for(provisional_name: nil, name_override: nil,
                  obs_taxon_name: nil)
    fake = FakeInatObs.new(sequences: [], quality_grade: "needs_id",
                           provisional_name: provisional_name,
                           name_override: name_override,
                           obs_taxon_name: obs_taxon_name)
    Inat::MoObservationBuilder.new(inat_obs: fake, user: users(:rolf),
                                   external_site: external_sites(:inaturalist))
  end

  def naming_vote(sequence:, provisional:, quality_grade:)
    fake = FakeInatObs.new(
      sequences: sequence ? [:a_sequence] : [],
      # An existing MO name, so resolving it needs no API post.
      provisional_name: provisional ? names(:lactarius_alpinus).text_name : nil,
      quality_grade: quality_grade
    )
    # external_site: :stub keeps the constructor from hitting
    # ExternalSite.inaturalist.
    Inat::MoObservationBuilder.new(
      inat_obs: fake, user: users(:rolf), external_site: :stub
    ).send(:naming_vote)
  end
end
