# frozen_string_literal: true

require("test_helper")

# Integration test for the `Query::Observations` instances that
# the 5 `Tab::Name::ObsLink::*` subclasses build. Constructs the
# 2-name synonymized x 3-consensus-arrangement fixture grid (6
# observations, 6 namings) and asserts that each Tab's query
# returns exactly the right rows. Migrated from
# `NamesHelperTest#test_observations_of_queries` after the
# observation-link helpers moved into the Tab POROs.
class Tab::Name::ObsLinkQueryIntegrationTest < UnitTestCase
  def test_observation_link_queries_return_correct_observations
    # 2 Names, synonymized; 6 Observations + 6 Namings:
    #   - nam_proposed_and_consensus       (nam, nam-naming)
    #   - nam_proposed_syn_is_consensus    (syn, syn-naming + nam-naming)
    #   - nam_proposed_other_taxon_is_consensus (other_taxon,
    #                                            nam-naming)
    #   - syn_proposed_and_consensus       (syn, syn-naming)
    #   - syn_proposed_nam_is_consensus    (nam, syn-naming + nam-naming)
    #   - syn_proposed_other_taxon_is_consensus (other_taxon,
    #                                            syn-naming)
    user        = users(:rolf)
    nam         = names(:lactarius_alpinus)
    syn         = names(:lactarius_alpigenes)  # synonym of nam
    other_taxon = names(:suillus)

    nam_proposed_and_consensus = create_obs_with_namings(
      name: nam, namings: [nam], user: user, notes: "nam_only"
    )
    nam_proposed_syn_is_consensus = create_obs_with_namings(
      name: syn, namings: [syn, nam], user: user, notes: "nam_syn"
    )
    nam_proposed_other_taxon_is_consensus = create_obs_with_namings(
      name: other_taxon, namings: [nam], user: user, notes: "nam_other"
    )
    syn_proposed_and_consensus = create_obs_with_namings(
      name: syn, namings: [syn], user: user, notes: "syn_only"
    )
    syn_proposed_nam_is_consensus = create_obs_with_namings(
      name: nam, namings: [syn, nam], user: user, notes: "syn_nam"
    )
    syn_proposed_other_taxon_is_consensus = create_obs_with_namings(
      name: other_taxon, namings: [syn], user: user, notes: "syn_other"
    )

    assert_any_name_query(
      nam,
      includes: [nam_proposed_and_consensus,
                 nam_proposed_syn_is_consensus,
                 syn_proposed_and_consensus,
                 syn_proposed_nam_is_consensus],
      excludes: [nam_proposed_other_taxon_is_consensus,
                 syn_proposed_other_taxon_is_consensus]
    )

    assert_other_names_query(
      nam,
      includes: [nam_proposed_syn_is_consensus,
                 syn_proposed_and_consensus],
      excludes: [nam_proposed_and_consensus,
                 syn_proposed_nam_is_consensus,
                 nam_proposed_other_taxon_is_consensus,
                 syn_proposed_other_taxon_is_consensus]
    )

    assert_taxon_proposed_query(
      nam,
      includes: [nam_proposed_other_taxon_is_consensus,
                 syn_proposed_other_taxon_is_consensus],
      excludes: [nam_proposed_and_consensus,
                 nam_proposed_syn_is_consensus,
                 syn_proposed_and_consensus,
                 syn_proposed_nam_is_consensus]
    )

    assert_name_proposed_query(
      nam,
      includes: [nam_proposed_and_consensus,
                 nam_proposed_syn_is_consensus,
                 syn_proposed_nam_is_consensus,
                 nam_proposed_other_taxon_is_consensus],
      excludes: [syn_proposed_and_consensus,
                 syn_proposed_other_taxon_is_consensus]
    )
  end

  private

  def create_obs_with_namings(name:, namings:, user:, notes:)
    obs = Observation.create(name: name, notes: notes, user: user)
    namings.each do |naming_name|
      Naming.create(observation: obs, name: naming_name, user: user)
    end
    obs
  end

  def query_for(klass, name)
    klass.new(name: name, count: 1, controller: nil).query
  end

  def assert_any_name_query(name, includes:, excludes:)
    results = query_for(Tab::Name::ObsLink::AnyName, name).results
    assert_query_returns(results, includes: includes, excludes: excludes)
  end

  def assert_other_names_query(name, includes:, excludes:)
    results = query_for(Tab::Name::ObsLink::OtherNames, name).results
    assert_query_returns(results, includes: includes, excludes: excludes)
  end

  def assert_taxon_proposed_query(name, includes:, excludes:)
    results = query_for(Tab::Name::ObsLink::TaxonProposed, name).results
    assert_query_returns(results, includes: includes, excludes: excludes)
  end

  def assert_name_proposed_query(name, includes:, excludes:)
    results = query_for(Tab::Name::ObsLink::NameProposed, name).results
    assert_query_returns(results, includes: includes, excludes: excludes)
  end

  def assert_query_returns(results, includes:, excludes:)
    includes.each do |obs|
      assert_includes(results, obs,
                      "expected #{obs.notes.inspect} in results")
    end
    excludes.each do |obs|
      assert_not_includes(results, obs,
                          "expected #{obs.notes.inspect} NOT in results")
    end
  end
end
