#  = Sequence Model
#
#  A nucleotide sequence associated with an Observation.
#  A Sequence must have: a Locus, either Bases and/or (Archive and Accession).
#  It may have Notes.
#
#  == Attributes
#
#  id::               unique numerical id, starting at 1.
#  observation::      associated Observation record
#  user::             user who created the Sequence
#  locus::            description of the locus (region) of the Sequence
#  bases::            nucleotides in FASTA format (description lines optional)
#  archive::          on-line database in which Sequence is archived
#  accession::        accession # in the Archive
#  notes::            free-form notes
#
#  == Class Methods
#
#  locus_width        Default # of chars (including diaresis) to truncate locus
#
#  == Instance Methods
#
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
  DESCRIPTION        = /\A>.*$/
  # nucleotide codes from http://www.bioinformatics.org/sms2/iupac.html
  # FASTA allows interspersed numbers, spaces. See https://goo.gl/NYbptK
  VALID_CODES        = /ACGTURYSWKMBDHVN.\-\d\s/i
  INVALID_CODES      = /[^#{VALID_CODES}]/i

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
  validate  :blastable, if: :bases?
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
  def blastable
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
    data =~ INVALID_CODES
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
