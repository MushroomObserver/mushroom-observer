# frozen_string_literal: true

require("test_helper")

# test the helpers for ObservationsController
class NamesHelperTest < ActionView::TestCase
  # Prove that the Query's used under "Observations of" (in the
  # show_name_info area) return the correct Observations
  include NamesHelper # Query's are in that helper

  def test_observations_of_queries
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
                  name: nam, user: user)

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
    results = obss_of_taxon_any_name(nam).results
    assert(results.include?(nam_proposed_and_consensus))
    assert(results.include?(nam_proposed_syn_is_consensus))
    assert(results.include?(syn_proposed_and_consensus))
    assert(results.include?(syn_proposed_nam_is_consensus))
    assert(results.exclude?(nam_proposed_other_taxon_is_consensus))
    assert(results.exclude?(syn_proposed_other_taxon_is_consensus))

    results = obss_of_taxon_other_names(nam).results
    assert(results.exclude?(nam_proposed_and_consensus))
    assert(results.include?(nam_proposed_syn_is_consensus))
    assert(results.include?(syn_proposed_and_consensus))
    assert(results.exclude?(syn_proposed_nam_is_consensus))
    assert(results.exclude?(nam_proposed_other_taxon_is_consensus))
    assert(results.exclude?(syn_proposed_other_taxon_is_consensus))

    results = obss_other_taxa_this_taxon_proposed(nam).results
    assert(results.exclude?(nam_proposed_and_consensus))
    assert(results.exclude?(nam_proposed_syn_is_consensus))
    assert(results.exclude?(syn_proposed_and_consensus))
    assert(results.exclude?(syn_proposed_nam_is_consensus))
    assert(results.include?(nam_proposed_other_taxon_is_consensus))
    assert(results.include?(syn_proposed_other_taxon_is_consensus))

    results = obss_this_name_proposed(nam).results
    assert(results.include?(nam_proposed_and_consensus))
    assert(results.include?(nam_proposed_syn_is_consensus))
    assert(results.exclude?(syn_proposed_and_consensus))
    assert(results.include?(syn_proposed_nam_is_consensus))
    assert(results.include?(nam_proposed_other_taxon_is_consensus))
    assert(results.exclude?(syn_proposed_other_taxon_is_consensus))
  end

  def test_names_index_sorts_without_query
    sorts = names_index_sorts
    keys = sorts.map(&:first)

    assert_equal(%w[name created_at updated_at num_views], keys)
  end

  def test_names_index_sorts_with_rss_log_query_maps_updated_to_rss_log
    query = Query.lookup(Name, order_by: :rss_log)
    sorts = names_index_sorts(query: query)
    keys = sorts.map(&:first)

    assert_includes(keys, "rss_log")
    assert_not_includes(keys, "updated_at")
  end

  def test_names_index_sorts_with_non_rss_log_query_uses_updated_at
    query = Query.lookup(Name, order_by: :name)
    sorts = names_index_sorts(query: query)
    keys = sorts.map(&:first)

    assert_includes(keys, "updated_at")
    assert_not_includes(keys, "rss_log")
  end
end
