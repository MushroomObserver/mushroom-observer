# encoding: utf-8

require "test_helper"

class SequenceTest < UnitTestCase
  def test_validators
    # Prove that Sequence with all proper fields is validated
    sequence = Sequence.new(
                    observation: observations(:boletus_edulis_obs),
                    user:        observations(:boletus_edulis_obs).user,
                    locus:       "ITS",
                    bases:       "ACGT",
                    archive:     "GenBank",
                    accession:   "KY366491.1",
                    notes:       "Random notes"
    )
    assert(sequence.valid?)

    # Prove that Sequence with a blank locus is invalid.
    sequence = Sequence.new(
                    observation: observations(:boletus_edulis_obs),
                    user:        observations(:boletus_edulis_obs).user,
                    locus:       "",
                    bases:       "ACGT",
                    archive:     "GenBank",
                    accession:   "KY366491.1",
                    notes:       "Random notes"
    )
    assert(sequence.invalid?)

    # Prove that Sequence with a blank observation is invalid.
    sequence = Sequence.new(
                    observation: nil,
                    user:        observations(:boletus_edulis_obs).user,
                    locus:       "ITS",
                    bases:       "ACGT",
                    archive:     "GenBank",
                    accession:   "KY366491.1",
                    notes:       "Random notes"
    )
    assert(sequence.invalid?)

    # Prove that Sequence with a blank user is invalid.
    sequence = Sequence.new(
                    observation: observations(:boletus_edulis_obs),
                    user:        nil,
                    locus:       "ITS",
                    bases:       "ACGT",
                    archive:     "GenBank",
                    accession:   "KY366491.1",
                    notes:       "Random notes"
    )
    assert(sequence.invalid?)

    # Prove that Sequence with bases present, archive & access blank is valid
    sequence = Sequence.new(
                    observation: observations(:boletus_edulis_obs),
                    user:        observations(:boletus_edulis_obs).user,
                    locus:       "ITS",
                    bases:       "ACGT",
                    archive:     "",
                    accession:   "",
                    notes:       "Random notes"
    )
    assert(sequence.valid?, :validate_sequence_bases_or_archive.l)

    # Prove that Sequence with bases blank, archive & access present is valid
    sequence = Sequence.new(
                    observation: observations(:boletus_edulis_obs),
                    user:        observations(:boletus_edulis_obs).user,
                    locus:       "ITS",
                    bases:       "",
                    archive:     "GenBank",
                    accession:   "KY366491.1",
                    notes:       "Random notes"
    )
    assert(sequence.valid?, :validate_sequence_bases_or_archive.l)

    # Prove that Sequence with blank bases, archive, and accession is invalid
    sequence = Sequence.new(
                    observation: observations(:boletus_edulis_obs),
                    user:        observations(:boletus_edulis_obs).user,
                    locus:       "ITS",
                    bases:       "",
                    archive:     "",
                    accession:   "",
                    notes:       "Random notes"
    )
    assert(sequence.invalid?, :validate_sequence_bases_or_archive.l)

    # Prove that Sequence with blank bases and archive is invalid
    sequence = Sequence.new(
                    observation: observations(:boletus_edulis_obs),
                    user:        observations(:boletus_edulis_obs).user,
                    locus:       "ITS",
                    bases:       "",
                    archive:     "",
                    accession:   "KY366491.1",
                    notes:       "Random notes"
    )
    assert(sequence.invalid?, :validate_sequence_bases_or_archive.l)

    # Prove that Sequence with blank bases and accession is invalid
    sequence = Sequence.new(
                    observation: observations(:boletus_edulis_obs),
                    user:        observations(:boletus_edulis_obs).user,
                    locus:       "ITS",
                    bases:       "",
                    archive:     "GenBank",
                    accession:   "",
                    notes:       "Random notes"
    )
    assert(sequence.invalid?, :validate_sequence_bases_or_archive.l)
  end
end
