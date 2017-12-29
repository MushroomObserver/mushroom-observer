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

    # Prove that Sequences Bases raw base codes must be unique for an Observation
    existing_seq = sequences(:local_sequence)
    obs = existing_seq.observation
    sequence = Sequence.new(
      observation: obs,
      user:        obs.user,
      locus:       "ITS",
      bases:       "  1 #{existing_seq.bases}",
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

  def test_bases_validators
    # Prove validity of accepted formats
    sequence = sequences(:bare_formatted_sequence)
    assert(sequence.valid?, sequence.errors.messages)

    sequence = sequences(:bare_with_numbers_sequence)
    assert(sequence.valid?, sequence.errors.messages)

    sequence = sequences(:fasta_formatted_sequence)
    assert(sequence.valid?, sequence.errors.messages)

    # Prove various formats invalid
    params = {
      observation: observations(:boletus_edulis_obs),
      user:        observations(:boletus_edulis_obs).user,
      locus:       "ITS",
      bases:       "ACGT",
      archive:     "GenBank",
      accession:   "KY366491.1",
      notes:       "Random notes"
    }

    # Prove bases with blank lines in the middle are invalid
    params[:bases] = "actg\r\n \r\n gtca"
    sequence = Sequence.new(params)
    assert(sequence.invalid?)

    # Prove we allow all IUPAC or FASTA nucleotide codes
    params[:bases] = "ACGTURYSWKMBDHVN.-0123456789 \n\r\t"
    sequence = Sequence.new(params)
    assert(sequence.valid?, "Bases should allow all valid nucleotide codes")

    # Prove bases with invalid nucleic acid codes are invalid
    params[:bases] = "acgt plus sOmE craP"
    sequence = Sequence.new(params)
    assert(sequence.invalid?, "Bases with invalid code should be invalid")
  end

  def test_deposit?
    # Prove it's false if neither archive nor accession
    refute(sequences(:local_sequence).deposit?)
    # Prove it's false if accession but no archive
    refute(sequences(:missing_archive_sequence).deposit?)
    # Prove it's false if archive but no accession
    refute(sequences(:missing_accession_sequence).deposit?)
    # Prove it's true if both archive and accession
    assert(sequences(:deposited_sequence).deposit?)
  end

  def test_accession_url
    sequence = sequences(:deposited_sequence)
    assert_equal("https://www.ncbi.nlm.nih.gov/nuccore/#{sequence.accession}",
                 sequence.accession_url)
  end

  def test_blast_url
    assert_equal(
      %(#{Sequence. blast_url_prefix}ACGT),
      sequences(:local_sequence).blast_url
    )
    assert_equal(
      %(#{Sequence.blast_url_prefix}KT968605),
      sequences(:deposited_sequence).blast_url
    )
    # Prove that BLAST url for UNITE sequence uses Bases instead of Accession.
    assert_equal(
      %(#{Sequence.blast_url_prefix}ACGT),
      sequences(:alternate_archive).blast_url
    )
    # Prove that BLAST url for FASTA formatted sequence
    # excludes description and whitespace
    expected_query = "" \
    "GGAAGTAAAAGTCGTAACAAGGTTTCCGTAGGTGAACCTGCGGAAGGATCATTACACAATACTCTGTATT" \
    "ATCCACACACACCTTCTGTGATCCATTTACCTGGTTGCTTCCCGTGGCATCTCGCTTGCTTCAGAGGCCC" \
    "CTGCCTTCCTGCGGGAGGGCAGGTGTGAGCTGCTGCTGGCCCCCCGGGACCACGGGAAGGTCCAATGAAA" \
    "CCCTGGTTTTTTGATGCCTTCAAGTCTGAAATTATTGAATACAAGAAAACTGTTAAAACTTTCAACAACG" \
    "GATCTCTTGGTTCTCGCATCGATGAAGAACGCAGCGAAATGCGATAAGTAGTGTGAATTGCAGAATTCAG" \
    "TGAATCATCGAATCTTTGAACGCACATTGCGCCCCCTGGCATTCCGGGGGGCACGCCTGTTCGAGCGTCA" \
    "TTAAGTCAACCCTCAAGCCTCCTTTGGTTTGGTCATGGAACTGAACGGCCGGACCCGCTTGGGATCCGGT" \
    "CGGTCTACTCCGAAATGCATTGTTGCGGAATGCCCCAGTCGGCACAGGCGTAGTGAATTTTCTATCATCG" \
    "TCTGTTTGTCCGCGAGGCGTTCCCGCCCACCGAACCCAATAAACCTTTCTCCTAGTTGACCTCGAATCAG" \
    "GTGGGG"

    assert_equal(
      %(#{Sequence.blast_url_prefix}#{expected_query}),
      sequences(:fasta_formatted_sequence).blast_url
    )

    # Prove that BLAST url for bare sequence
    # excludes digits and whitespace
    expected_query = "" \
    "ggaagtaaaagtcgtaacaaggtttccgtaggtgaacctgcggaaggatcattacacaat"\
    "actctgtattatccacacacaccttctgtgatccatttacctggttgcttcccgtggcat"\
    "ctcgcttgcttcagaggcccctgccttcctgcgggagggcaggtgtgagctgctgctggc"\
    "cccccgggaccacgggaaggtccaatgaaaccctggttttttgatgccttcaagtctgaa"\
    "attattgaatacaagaaaactgttaaaactttcaacaacggatctcttggttctcgcatc"\
    "gatgaagaacgcagcgaaatgcgataagtagtgtgaattgcagaattcagtgaatcatcg"\
    "aatctttgaacgcacattgcgccccctggcattccggggggcacgcctgttcgagcgtca"\
    "ttaagtcaaccctcaagcctcctttggtttggtcatggaactgaacggccggacccgctt"\
    "gggatccggtcggtctactccgaaatgcattgttgcggaatgccccagtcggcacaggcg"\
    "tagtgaattttctatcatcgtctgtttgtccgcgaggcgttcccgcccaccgaacccaat"\
    "aaacctttctcctagttgacctcgaatcaggtggggB"

    assert_equal(
      %(#{Sequence.blast_url_prefix}#{expected_query}),
      sequences(:bare_with_numbers_sequence).blast_url
    )
  end
end
