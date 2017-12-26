#  = Sequence Model
#
#  A nucleotide sequence associated with an Observation.
#  A Sequence must have: a Locus, either Bases and/or (Archive and Accession).
#  It may have Notes.
#
#  == Attributes
#
#  id::                unique numerical id, starting at 1.
#  observation::       associated Observation record
#  user::              user who created the Sequence
#  locus::             description of the locus (region) of the Sequence
#  bases::             nucleotides in FASTA format (description lines optional)
#  archive::           on-line database in which Sequence is archived
#  accession::         accession # in the Archive
#  notes::             free-form notes
#
#  == Class Methods
#
#  blast_url_prefix    part of url prepended to BLAST QUERY
#  locus_width         Default # of chars (including diaresis) to truncate locus
#
#  == Instance Methods
#
#  accession_url       url of a search for accession
#  blast_url           url of NCBI page to create a BLAST report
#  blastable?          Can we easily create a blast_url for the Sequence?
#  deposit?            Does sequence have a deposit (both Archive && Accession)
#  format_name         name for orphaned objects
#  locus_width         Default # of chars (including diaresis) to truncate locus
#  unique_format_name  name for unorphaned objects
#
class Sequence < AbstractModel
  belongs_to :observation
  belongs_to :user

  after_create  :log_add_sequence
  after_update  :log_update_sequence
  after_destroy :log_destroy_sequence

  ##############################################################################
  #
  #  :section: Matchers
  #
  ##############################################################################

  # matchers for bases
  BLANK_LINE_IN_MIDDLE = /(\s*)\S.*\n # non-blank line
                          ^\s*\n      # followed by blank line
                          (\s*)\S/x   # and later non-whitespace character
  DESCRIPTION          = /\A>.*$/
  # nucleotide codes from http://www.bioinformatics.org/sms2/iupac.html
  VALID_CODES          = /ACGTURYSWKMBDHVN.\-/i
  # FASTA allows interspersed numbers, whitespace. See https://goo.gl/NYbptK
  VALID_BASE_CHARS     = /#{VALID_CODES}\d\s/i
  INVALID_BASE_CHARS   = /[^#{VALID_BASE_CHARS}]/i

  ##############################################################################
  #
  #  :section: Formatting
  #
  ##############################################################################

  # used in views and by MatrixBoxPresenter to show orphaned obects
  def format_name
    locus.truncate(locus_width, separator: " ")
  end

  # used in views and by MatrixBoxPresenter to show unorphaned obects
  def unique_format_name
    format_name + " (Sequence #{id || "?"})"
  end

  # Default number of characters (including diaresis) for truncating locus
  def self.locus_width
    24
  end

  # wrapper around class method
  def locus_width
    Sequence.locus_width
  end

  ##############################################################################
  #
  #  :section: Other
  #
  ##############################################################################

  # Can we easily create a blast_url for the Sequence?
  #   ("easily" == without using 3d party API to get the BLAST QUERY parameter)
  def blastable?
    blastable_by_accession? || bases.present?
  end

  # Does using Accession as BLAST's QUERY parameter give a good BLAST report?
  # I.e., are the Archive's accession numbers == Genbank's accession numbers?
  # (UNITE Accessions are not in GenBank.)
  def blastable_by_accession?
    archive.present? && WebSequenceArchive.accession_blastable?(archive)
  end

  # url of NCBI page to set up BLAST for the Sequence
  def blast_url
    if blastable_by_accession?
      "#{blast_url_prefix}#{accession.gsub(/\s/, "")}"
    else
      "#{blast_url_prefix}#{bases_nucleotides}"
    end
  end

  def self.blast_url_prefix
    "https://blast.ncbi.nlm.nih.gov/Blast.cgi?" \
    "CMD=Put&DATABASE=nt&PROGRAM=blastn&QUERY="
  end

  # convenience wrapper around class method of same name
  def blast_url_prefix
    Sequence.blast_url_prefix
  end

  # Just the nucleotide codes: no description, no digits, no whitespace
  def bases_nucleotides
    bases.sub(DESCRIPTION, "").gsub(/[\d\s]/, "")
  end

  def deposit?
    archive.present? && accession.present?
  end

  # url of a search for accession
  def accession_url
    WebSequenceArchive.search_prefix(archive) << accession
  end

  ##############################################################################

  protected

  ##############################################################################
  #
  #  :section: Logging
  #
  ##############################################################################

  # Callbacks to log Sequence modifications in associated Observation

  def log_add_sequence
    observation.log_add_sequence(self)
  end

  def log_update_sequence
    if accession_added?
      # Log accession and put at top of RSS feed
      observation.log_accession_sequence(self)
    else
      observation.log_update_sequence(self)
    end
  end

  def log_destroy_sequence
    observation.log_destroy_sequence(self)
  end

  def accession_added?
    accession_changed? && accession_was_blank? && accession.present?
  end

  def accession_changed?
    changes[:accession].present?
  end

  def accession_was_blank?
    changes[:accession].first.blank?
  end

  ##############################################################################
  #
  #  :section: Validation
  #
  ##############################################################################

  # Validations, in order that error messages should appear in flash
  validates :locus, :observation, :user, presence: true
  validates :archive, length: { maximum: 255 }
  validates :accession, length: { maximum: 255 }
  validate  :bases_or_deposit
  validate  :deposit_complete_or_absent
  validate  :unique_bases_for_obs, if: :bases?
  validate  :bases_blastable, if: :bases?
  validate  :unique_accession_for_obs

  # Valid Sequence must include bases &/or deposit (archive & accession)
  # because MO-sourced sequence information should not be secret
  def bases_or_deposit
    return if bases? || deposit?
    errors.add(:bases, :validate_sequence_bases_or_archive.t)
  end

  # Valid deposit must have both archive && accession or neither.
  # (One without the other is not useful.)
  def deposit_complete_or_absent
    return if archive.present? == accession.present?
    errors.add(:archive, :validate_sequence_deposit_complete.t)
  end

  # Valid Sequence should have unique bases
  # Prevents duplicate Sequences for the same Observation
  def unique_bases_for_obs
    return unless other_sequences_same_obs.any? do |other_sequence|
      other_sequence.bases == bases
    end
    errors.add(:bases, :validate_sequence_bases_unique.t)
  end

  # array of other Sequences in same Observation
  def other_sequences_same_obs
    observation.try(:sequences) ? observation.sequences - [self] : []
  end

  # Validate proper formatting of bases
  # See BLAST documentation (shortened url: https://goo.gl/NYbptK)
  # full url in WebSequenceArchive::blast_format_help
  def bases_blastable
    if blank_line_in_middle?
      errors.add(:bases, :validate_sequence_bases_blank_lines.t)
    end
    return unless bad_code_in_data?
    errors.add(:bases, :validate_sequence_bases_bad_codes.t)
  end

  def blank_line_in_middle?
    bases =~ BLANK_LINE_IN_MIDDLE
  end

  def bad_code_in_data?
    # remove any description line
    data = bases.sub(DESCRIPTION, "")
    data =~ INVALID_BASE_CHARS
  end

  # Valid Sequence cannnot have duplicate accessions
  # Prevents duplicate Sequences for the same Observation
  def unique_accession_for_obs
    return if accession.blank?
    return unless other_sequences_same_obs.any? do |sequence|
      sequence.accession == accession
    end
    errors.add(:bases, :validate_sequence_accession_unique.t)
  end
end
