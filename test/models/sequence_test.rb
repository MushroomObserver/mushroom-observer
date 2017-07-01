require "test_helper"

class SequenceTest < UnitTestCase
  def test_validators
    # Prove that Sequence with all proper fields is valid.
    sequence = Sequence.new(
      observation: observations(:boletus_edulis_obs),
      user:        observations(:boletus_edulis_obs).user,
      locus:       "ITS",
      bases:       "ACGT",
      archive:     "GenBank",
      accession:   "KY366491.1",
      notes:       "Random notes"
    )
    assert(sequence.valid?, sequence.errors.messages)

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

    # Prove that Sequence with blank bases and blank accession is invalid
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

    # Prove that Sequence with archive but no accession is invalid
    sequence = Sequence.new(
      observation: observations(:boletus_edulis_obs),
      user:        observations(:boletus_edulis_obs).user,
      locus:       "ITS",
      bases:       "acgt",
      archive:     "GenBank",
      accession:   "",
      notes:       "Random notes"
    )
    assert(sequence.invalid?, :validate_sequence_deposit_complete.l)

    # Prove that Sequence with accession but no archive is invalid
    sequence = Sequence.new(
      observation: observations(:boletus_edulis_obs),
      user:        observations(:boletus_edulis_obs).user,
      locus:       "ITS",
      bases:       "acgt",
      archive:     "",
      accession:   "KY366491",
      notes:       "Random notes"
    )
    assert(sequence.invalid?, :validate_sequence_deposit_complete.l)

    # Prove that Sequences Bases must be unique for an Observation
    existing_seq = sequences(:local_sequence)
    obs = existing_seq.observation
    sequence = Sequence.new(
      observation: obs,
      user:        obs.user,
      locus:       "ITS",
      bases:       existing_seq.bases,
      archive:     "",
      accession:   "",
      notes:       "Random notes"
    )
    assert(sequence.invalid?, :validate_sequence_bases_unique.l)

    # Prove Observation can have Sequences with non-unique, blank Bases
    existing_seq = sequences(:deposited_sequence)
    obs = existing_seq.observation
    sequence = Sequence.new(
      observation: obs,
      user:        obs.user,
      locus:       "ITS",
      bases:       "", # same as existing_seq
      archive:     "GenBank",
      accession:   "#{existing_seq.accession}2",
      notes:       "Random notes"
    )
    assert(sequence.valid?, :validate_sequence_accession_unique.l)

    # Prove that Sequence Accessions must be unique for an Observation
    existing_seq = sequences(:deposited_sequence)
    obs = existing_seq.observation
    sequence = Sequence.new(
      observation: obs,
      user:        obs.user,
      locus:       "ITS",
      bases:       "",
      archive:     "GenBank",
      accession:   existing_seq.accession,
      notes:       "Random notes"
    )
    assert(sequence.invalid?, :validate_sequence_accession_unique.l)

    # Prove Observation can have Sequences with non-unique, blank Accessions
    existing_seq = sequences(:local_sequence)
    obs = existing_seq.observation
    sequence = Sequence.new(
      observation: obs,
      user:        obs.user,
      locus:       "ITS",
      bases:       "#{existing_seq.bases}a",
      archive:     "",
      accession:   "", # same as existing_sequence
      notes:       "Random notes"
    )
    assert(sequence.valid?, :validate_sequence_accession_unique.l)
  end

  def test_accession_url
    assert_equal("https://www.ncbi.nlm.nih.gov/nuccore/KY366491.1",
                 sequences(:deposited_sequence).accession_url)
  end
end
