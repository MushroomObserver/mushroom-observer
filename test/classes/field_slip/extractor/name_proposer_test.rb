# frozen_string_literal: true

require("test_helper")

class FieldSlip::Extractor::NameProposerTest < UnitTestCase
  def setup
    @obs = observations(:minimal_unknown_obs)
  end

  def propose(given, user: rolf, vote: nil, approved: nil, chosen: nil)
    FieldSlip::Extractor::NameProposer.new(
      observation: @obs, user: user, vote: vote,
      name_params: { given_name: given, approved_name: approved,
                     chosen_name: chosen }
    ).propose
  end

  def test_nothing_to_propose_when_the_id_is_blank
    before = @obs.namings.count

    ["", "   ", nil].each do |blank|
      outcome = propose(blank)

      assert_equal(:none, outcome.status)
    end
    assert_equal(before, @obs.reload.namings.count)
  end

  # ---------- a name MO already holds ----------

  def test_proposes_a_known_name
    before = @obs.namings.count

    outcome = propose("Coprinus comatus")

    assert_predicate(outcome, :proposed?)
    assert_equal(before + 1, @obs.reload.namings.count)
    assert_equal("Coprinus comatus", outcome.naming.name.text_name)
  end

  # An admin reading someone else's slip is stating their own reading of
  # it, so the naming and the vote are theirs, not the owner's.
  def test_naming_is_attributed_to_the_reviewer
    assert_not_equal(@obs.user, dick, "premise: reviewer is not the owner")

    outcome = propose("Coprinus comatus", user: dick)

    assert_equal(dick, outcome.naming.user)
  end

  def test_casts_the_requested_vote
    outcome = propose("Coprinus comatus", vote: Vote::MAXIMUM_VOTE.to_s)
    vote = Vote.find_by(naming: outcome.naming, user: rolf)

    assert_equal(Vote::MAXIMUM_VOTE, vote.value)
  end

  # Relaying what a slip says is not asserting a determination, so the
  # weakest positive value is the default.
  def test_vote_defaults_to_the_weakest_positive_value
    outcome = propose("Coprinus comatus")
    vote = Vote.find_by(naming: outcome.naming, user: rolf)

    assert_equal(Vote::MIN_POS_VOTE, vote.value)
  end

  def test_unusable_vote_falls_back_to_the_default
    outcome = propose("Coprinus comatus", vote: "not a number")
    vote = Vote.find_by(naming: outcome.naming, user: rolf)

    assert_equal(Vote::MIN_POS_VOTE, vote.value)
  end

  # ---------- a name MO does not hold ----------

  # The whole point of the round-trip: a machine reading never mints a
  # Name on its own.
  def test_unknown_name_asks_before_creating_anything
    names_before = Name.count
    namings_before = @obs.namings.count

    outcome = propose("Lumpy Bracket")

    assert_predicate(outcome, :needs_approval?)
    assert_equal(names_before, Name.count)
    assert_equal(namings_before, @obs.reload.namings.count)
  end

  # The resolver's own ivars drive the form's "create this name?" UI,
  # so they have to survive the trip back.
  def test_needs_approval_carries_the_resolvers_feedback
    outcome = propose("Lumpysomething bracketii")

    assert(outcome.feedback.key?(:names))
    assert_not(outcome.feedback.key?(:success),
               "success is the status, not feedback")
  end

  def test_approved_name_is_created_and_proposed
    names_before = Name.count

    outcome = propose("Lumpysomething bracketii",
                      approved: "Lumpysomething bracketii")

    assert_predicate(outcome, :proposed?)
    assert_operator(Name.count, :>, names_before)
    assert_equal("Lumpysomething bracketii", outcome.naming.name.text_name)
  end

  # Choosing among same-named authors goes through the same resolver
  # path the observation form uses.
  def test_chosen_name_resolves_to_that_record
    name = names(:coprinus_comatus)

    outcome = propose("anything at all", chosen: name.id.to_s)

    assert_predicate(outcome, :proposed?)
    assert_equal(name, outcome.naming.name)
  end

  # The resolver treats "unknown" as no opinion, so it neither resolves
  # nor asks to create anything. Note "Fungi" is NOT one of these: it is
  # a real Name and proposing it is legitimate, if uninformative.
  def test_placeholder_names_propose_nothing
    names_before = Name.count

    Name.names_for_unknown.compact_blank.uniq.each do |placeholder|
      outcome = propose(placeholder)

      assert_predicate(outcome, :needs_approval?,
                       "#{placeholder.inspect} should not resolve")
    end
    assert_equal(names_before, Name.count)
  end
end
