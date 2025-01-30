# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Sequences class to be included in QueryTest
class Query::SequencesTest < UnitTestCase
  include QueryExtensions

  def test_sequence_all
    expects = Sequence.index_order
    assert_query(expects, :Sequence)
  end

  def test_sequence_locus_has
    assert_query(Sequence.where(Sequence[:locus].matches("ITS%")).
                 index_order.distinct,
                 :Sequence, locus_has: "ITS")
  end

  def test_sequence_archive
    assert_query([sequences(:alternate_archive)],
                 :Sequence, archive: "UNITE")
  end

  def test_sequence_accession_has
    assert_query([sequences(:deposited_sequence)],
                 :Sequence, accession_has: "968605")
  end

  def test_sequence_notes_has
    assert_query([sequences(:deposited_sequence)],
                 :Sequence, notes_has: "deposited_sequence")
  end

  def test_sequence_for_observations
    obs = observations(:locally_sequenced_obs)
    assert_query([sequences(:local_sequence)],
                 :Sequence, observations: [obs.id])
  end

  def test_sequence_filters
    sequences = Sequence.reorder(id: :asc).all
    seq1 = sequences[0]
    seq2 = sequences[1]
    seq3 = sequences[3]
    seq4 = sequences[4]
    seq1.update(observation: observations(:minimal_unknown_obs))
    seq2.update(observation: observations(:detailed_unknown_obs))
    seq3.update(observation: observations(:agaricus_campestris_obs))
    seq4.update(observation: observations(:peltigera_obs))
    assert_query([seq1, seq2], :Sequence, obs_date: %w[2006 2006])
    assert_query([seq1, seq2], :Sequence, observers: users(:mary))
    assert_query([seq1, seq2], :Sequence, names: "Fungi")
    assert_query([seq4], :Sequence,
                 names: "Petigera", include_synonyms: true)
    expects = Sequence.index_order.joins(:observation).
              where(observations: { location: locations(:burbank) }).
              or(Sequence.index_order.joins(:observation).
                 where(Observation[:where].matches("Burbank"))).distinct
    assert_query(expects, :Sequence, locations: "Burbank")
    assert_query([seq2], :Sequence, projects: "Bolete Project")
    assert_query([seq1, seq2], :Sequence,
                 species_lists: "List of mysteries")
    assert_query([seq4], :Sequence, confidence: "2")
    # The test returns these sequences in random order, can't work.
    # assert_query([seq1, seq2, seq3], :Sequence,
    #              north: "90", south: "0", west: "-180", east: "-100")
  end

  def test_uses_join_hash
    query = Query.lookup(:Sequence,
                         north: "90", south: "0", west: "-180", east: "-100")
    assert_not(query.uses_join_sub([], :location))
    assert(query.uses_join_sub([:location], :location))
    assert_not(query.uses_join_sub({}, :location))
    assert(query.uses_join_sub({ test: :location }, :location))
    assert(query.uses_join_sub(:location, :location))
  end

  def test_sequence_in_set
    list_set_ids = [sequences(:fasta_formatted_sequence).id,
                    sequences(:bare_formatted_sequence).id]
    assert_query(list_set_ids, :Sequence, ids: list_set_ids)
  end

  def test_sequence_pattern_search
    assert_query([], :Sequence, pattern: "nonexistent")
    assert_query(Sequence.where(Sequence[:locus].matches("ITS%")).
                 index_order.distinct,
                 :Sequence, pattern: "ITS")
    assert_query([sequences(:alternate_archive)],
                 :Sequence, pattern: "UNITE")
    assert_query([sequences(:deposited_sequence)],
                 :Sequence, pattern: "deposited_sequence")
  end
end
