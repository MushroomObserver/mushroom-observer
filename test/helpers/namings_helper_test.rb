# frozen_string_literal: true

require("test_helper")

# Tests for NamingsHelper occurrence-related methods
class NamingsHelperTest < ActionView::TestCase
  include NamingsHelper
  include ObjectLinkHelper

  def setup
    @obs1 = observations(:minimal_unknown_obs)
    @obs2 = observations(:detailed_unknown_obs)
    @obs1.update_column(:occurrence_id, nil)
    @user = users(:rolf)
    User.current = @user
  end

  # -- best_user_vote --

  def test_best_user_vote_with_merged_naming
    create_occurrence(@obs1, @obs2)
    name = names(:agaricus_campestris)
    naming1 = Naming.create!(
      observation: @obs1, name: name, user: @user
    )
    naming2 = Naming.create!(
      observation: @obs2, name: name, user: users(:mary)
    )

    # Create votes with different values
    Vote.create!(naming: naming1, observation: @obs1,
                 user: @user, value: 2, favorite: true)
    Vote.create!(naming: naming2, observation: @obs2,
                 user: @user, value: 3, favorite: true)

    obs = Observation.naming_includes.find(@obs1.id)
    consensus = Observation::NamingConsensus.new(obs)
    merged = consensus.merged_namings.find do |mn|
      mn.name_id == name.id
    end
    assert_not_nil(merged, "Should find merged naming")

    vote = best_user_vote(merged, @user, consensus)
    assert_equal(3, vote.value,
                 "Should return highest vote across namings")
  end

  def test_best_user_vote_with_regular_naming
    obs = Observation.naming_includes.find(
      observations(:coprinus_comatus_obs).id
    )
    consensus = Observation::NamingConsensus.new(obs)
    naming = namings(:coprinus_comatus_naming)
    vote = best_user_vote(naming, @user, consensus)
    assert_not_nil(vote)
  end

  # -- naming_proposer_html --

  def test_naming_proposer_html_with_single_proposer
    naming = namings(:coprinus_comatus_naming)
    html = naming_proposer_html(naming)
    assert_match(naming.user.login, html)
  end

  def test_naming_proposer_html_with_multiple_proposers
    obs3 = observations(:amateur_obs)
    create_occurrence(@obs1, @obs2, obs3)
    name = names(:agaricus_campestris)
    # No local naming on obs1 -- only sibling namings with
    # different users triggers multiple_proposers?
    Naming.create!(
      observation: @obs2, name: name, user: @user
    )
    Naming.create!(
      observation: obs3, name: name, user: users(:mary)
    )

    obs = Observation.naming_includes.find(@obs1.id)
    consensus = Observation::NamingConsensus.new(obs)
    merged = consensus.merged_namings.find do |mn|
      mn.name_id == name.id
    end
    assert_not_nil(merged)
    assert(merged.multiple_proposers?,
           "Should have multiple proposers")

    html = naming_proposer_html(merged)
    assert_match(
      :show_observation_matching_observations.l, html,
      "Should show 'See Matching Observations' link"
    )
  end

  # -- merged_reasons_html --

  def test_merged_reasons_html_with_local_and_sibling_reasons
    create_occurrence(@obs1, @obs2)
    name = names(:agaricus_campestris)
    naming1 = Naming.create!(
      observation: @obs1, name: name, user: @user
    )
    naming2 = Naming.create!(
      observation: @obs2, name: name, user: users(:mary)
    )
    # Set reasons using update_reasons
    naming1.update_reasons(1 => "Local reason text")
    naming1.save!
    naming2.update_reasons(1 => "Sibling reason text")
    naming2.save!

    obs = Observation.naming_includes.find(@obs1.id)
    consensus = Observation::NamingConsensus.new(obs)
    merged = consensus.merged_namings.find do |mn|
      mn.name_id == name.id
    end
    assert_not_nil(merged)

    html = merged_reasons_html(merged)
    assert_match("Local reason text", html)
    assert_match("Sibling reason text", html)
    assert_match("MO #{@obs2.id}", html,
                 "Should include sibling observation link")
  end

  private

  def create_occurrence(primary_obs, *other_obs)
    occ = Occurrence.create!(
      user: @user,
      primary_observation: primary_obs
    )
    primary_obs.update!(occurrence: occ)
    other_obs.each { |obs| obs.update!(occurrence: occ) }
    occ
  end
end
