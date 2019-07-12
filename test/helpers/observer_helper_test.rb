# frozen_string_literal: true

require "test_helper"

# test the helpers for ObserverController
class ObserverHelperTest < ActionView::TestCase
  def test_show_observation_name
    user = users(:rolf)
    location = locations(:albion)

    # approved name
    current_name = names(:lactarius_alpinus)
    Observation.new(
      name: current_name, user: user, when: Time.current, where: location
    )
    assert_match(
      link_to(current_name.display_name_brief_authors.t,
              controller: :name,
              action: :show_name, id: current_name.id),
      obs_title_consensus_id(current_name),
      "Observation of a current Name should link to that Name"
    )

    # deprecated name
    deprecated_name = names(:lactarius_alpigenes)
    Observation.new(
      name: deprecated_name, user: user, when: Time.current, where: location
    )
    assert_match(
      "#{link_to_display_name_brief_authors(deprecated_name)} (Site ID) " \
      "(#{link_to_display_name_without_authors(current_name)})",
      obs_title_consensus_id(deprecated_name),
      "Observation of deprecated Name should link to it and approved Name"
    )
  end

  include ShowNameHelper

  # Prove that the Query's used under "Observations of" (in the
  # show_name_info area) return the correct Observations
  def test_obs_show_name_info_queries
    # Create 2 Names, synonymized; 6 Observations, 6 Namings:
    # Name n, Name s,
    # n and s synonymized.
    # Each of n and s needs:
    # an Observation where it's a naming and it's the consensus
    # an Observation where it's a naming but its synonym is the consensus
    # an Observation where it's a naming but neither is the consensus.
    user        = users(:rolf)
    nam         = names(:lactarius_alpinus)
    syn         = names(:lactarius_alpigenes) # a synonym of nam
    other_taxon = names(:suillus)

    # Observations where nam proposed
    nam_proposed_and_consensus =
      Observation.create(name: nam,
                         notes: "nam_proposed_and_consensus", # for debugging
                         user: user)
    Naming.create(observation: nam_proposed_and_consensus, name: nam,
                  user: user)

    nam_proposed_syn_is_consensus =
      Observation.create(name: syn,
                         notes: "nam_proposed_and_consensus", # for debugging
                         user: user)
    Naming.create(observation: nam_proposed_syn_is_consensus, name: syn,
                  user: user)
    Naming.create(observation: nam_proposed_syn_is_consensus, name: nam,
                  user: user)

    nam_proposed_other_taxon_is_consensus =
      Observation.create(name: other_taxon,
                         notes: "nam_proposed_other_taxon_is_consensus",
                         user: user)
    Naming.create(observation: nam_proposed_other_taxon_is_consensus,
                  name: syn, user: user)

    # Observations where syn proposed
    syn_proposed_and_consensus =
      Observation.create(name: syn,
                         notes: "syn_proposed_and_consensus",
                         user: user)
    Naming.create(observation: syn_proposed_and_consensus, name: syn,
                  user: user)

    syn_proposed_nam_is_consensus =
      Observation.create(name: nam,
                         notes: "syn_proposed_nam_is_consensus",
                         user: user)
    Naming.create(observation: syn_proposed_nam_is_consensus, name: syn,
                  user: user)
    Naming.create(observation: syn_proposed_nam_is_consensus, name: nam,
                  user: user)

    syn_proposed_other_taxon_is_consensus =
      Observation.create(name: other_taxon,
                         notes: "syn_proposed_other_taxon_is_consensus",
                         user: user)
    Naming.create(observation: syn_proposed_other_taxon_is_consensus, name: syn,
                  user: user)

    # Now test the Query's
    results = obss_of_taxon(nam).results
    assert results.include?(nam_proposed_and_consensus)
    assert results.include?(nam_proposed_syn_is_consensus)
    assert results.include?(syn_proposed_and_consensus)
    assert results.include?(syn_proposed_nam_is_consensus)
    assert results.exclude?(nam_proposed_other_taxon_is_consensus)
    assert results.exclude?(syn_proposed_other_taxon_is_consensus)

    results = obss_of_taxon_other_names(nam).results
    assert results.exclude?(nam_proposed_and_consensus)
    assert results.include?(nam_proposed_syn_is_consensus)
    assert results.include?(syn_proposed_and_consensus)
    assert results.exclude?(syn_proposed_nam_is_consensus)
    assert results.exclude?(nam_proposed_other_taxon_is_consensus)
    assert results.exclude?(syn_proposed_other_taxon_is_consensus)

    results = obss_other_taxa_this_name_proposed(nam).results
    assert results.exclude?(nam_proposed_and_consensus)
    assert results.exclude?(nam_proposed_syn_is_consensus)
    assert results.exclude?(syn_proposed_and_consensus)
    assert results.exclude?(syn_proposed_nam_is_consensus)
    assert results.include?(nam_proposed_other_taxon_is_consensus)
    assert results.exclude?(syn_proposed_other_taxon_is_consensus)

    results = obss_other_taxa_this_taxon_proposed(nam).results
    assert results.exclude?(nam_proposed_and_consensus)
    assert results.exclude?(nam_proposed_syn_is_consensus)
    assert results.exclude?(syn_proposed_and_consensus)
    assert results.exclude?(syn_proposed_nam_is_consensus)
    assert results.include?(nam_proposed_other_taxon_is_consensus)
    assert results.include?(syn_proposed_other_taxon_is_consensus)
  end
end
