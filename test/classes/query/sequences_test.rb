# frozen_string_literal: true

require "test_helper"
require "query_extensions"

# tests of Query::Sequences class to be included in QueryTest
class Query::SequencesTest < UnitTestCase
  include QueryExtensions

  def test_sequence_all
    expects = Sequence.index_order
    assert_query(expects, :Sequence)
  end

  def test_sequence_id_in_set
    ids = [sequences(:fasta_formatted_sequence).id,
           sequences(:bare_formatted_sequence).id]
    scope = Sequence.id_in_set(ids).index_order
    assert_query_scope(ids, scope, :Sequence, id_in_set: ids)
  end

  def test_sequence_locus
    ids = [sequences(:fasta_formatted_sequence)]
    scope = Sequence.locus("ITS1F").index_order
    assert_query_scope(ids, scope, :Sequence, locus: "ITS1F")
  end

  def sequences_with_its_locus
    [
      sequences(:bare_with_numbers_sequence),
      sequences(:bare_formatted_sequence),
      sequences(:fasta_formatted_sequence)
    ]
  end

  def test_sequence_locus_has
    ids = sequences_with_its_locus.map(&:id)
    scope = Sequence.locus_has("ITS").index_order
    assert_query_scope(ids, scope, :Sequence, locus_has: "ITS")
  end

  def test_sequence_archive
    ids = [sequences(:alternate_archive)]
    scope = Sequence.archive("UNITE").index_order
    assert_query_scope(ids, scope, :Sequence, archive: "UNITE")
  end

  def test_sequence_accession
    ids = [sequences(:deposited_sequence)]
    scope = Sequence.accession("KT968605").index_order
    assert_query_scope(ids, scope, :Sequence, accession: "KT968605")
  end

  def test_sequence_accession_has
    ids = [sequences(:deposited_sequence)]
    scope = Sequence.accession_has("968605").index_order
    assert_query_scope(ids, scope, :Sequence, accession_has: "968605")
  end

  def test_sequence_notes_has
    ids = [sequences(:deposited_sequence)]
    scope = Sequence.notes_has("deposited_sequence").index_order
    assert_query_scope(ids, scope, :Sequence, notes_has: "deposited_sequence")
  end

  def test_sequence_for_observations
    obs = observations(:locally_sequenced_obs)
    ids = [sequences(:local_sequence)]
    scope = Sequence.observations(obs).index_order
    assert_query_scope(ids, scope, :Sequence, observations: [obs.id])
  end

  def test_sequence_pattern_search
    assert_query([], :Sequence, pattern: "nonexistent")

    ids = sequences_with_its_locus.map(&:id)
    scope = Sequence.pattern("ITS").index_order
    assert_query_scope(ids, scope, :Sequence, pattern: "ITS")

    assert_query([sequences(:alternate_archive)],
                 :Sequence, pattern: "UNITE")
    assert_query([sequences(:deposited_sequence)],
                 :Sequence, pattern: "deposited_sequence")
  end

  def test_sequence_observation_query
    sequences = Sequence.reorder(id: :asc).all
    seq1 = sequences[0]
    seq2 = sequences[1]
    seq3 = sequences[3]
    seq4 = sequences[4]
    seq1.update(observation: observations(:minimal_unknown_obs))
    seq2.update(observation: observations(:detailed_unknown_obs))
    seq3.update(observation: observations(:agaricus_campestris_obs))
    seq4.update(observation: observations(:peltigera_obs))
    assert_query([seq1, seq2],
                 :Sequence, observation_query: { date: %w[2006 2006] })
    assert_query([seq1, seq2],
                 :Sequence, observation_query: { by_users: users(:mary) })
    assert_query([seq1, seq2],
                 :Sequence, observation_query: { names: { lookup: "Fungi" } })
    assert_query(
      [seq4], :Sequence, observation_query: {
        names: { lookup: "Petigera", include_synonyms: true }
      }
    )
    expects = Sequence.index_order.joins(:observation).
              where(observations: { location: locations(:burbank) }).
              or(Sequence.index_order.joins(:observation).
                 where(Observation[:where].matches("Burbank"))).distinct
    assert_query(expects,
                 :Sequence, observation_query: { locations: "Burbank" })
    assert_query([seq2],
                 :Sequence, observation_query: { projects: "Bolete Project" })
    assert_query(
      [seq1, seq2],
      :Sequence, observation_query: { species_lists: "List of mysteries" }
    )
    assert_query([seq4], :Sequence, observation_query: { confidence: "2" })
    # The test returns these sequences in random order, can't work.
    # assert_query(
    #   [seq1, seq2, seq3],
    #   :Sequence, observation_query: {
    #     in_box: { north: "90", south: "0", west: "-180", east: "-100" }
    #   }
    # )
  end

  def test_uses_join_hash
    box = { north: "90", south: "0", west: "-180", east: "-100" }
    query = Query.lookup(:Sequence, observation_query: { in_box: box })
    assert_not(query.uses_join_sub([], :location))
    assert(query.uses_join_sub([:location], :location))
    assert_not(query.uses_join_sub({}, :location))
    assert(query.uses_join_sub({ test: :location }, :location))
    assert(query.uses_join_sub(:location, :location))
  end
end
