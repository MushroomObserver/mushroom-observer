#  = Sequence Model
#
#  A nucleotide sequence associated with an Observation.
#  A Sequence must have: a Locus, either Bases and/or (Archive and Accession).
#  It may have Notes.
#
#  == Attributes
#
#  id::               unique numerical id, starting at 1.
#  observation::      id of the associated Observation
#  user::             user who created the Sequence
#  locus::            description of the locus (region) of the Sequence
#  bases::            nucleotides in FASTA format (description lines optional)
#  archive::          on-line database in which Sequence is archived
#  accession::        accession # in the Archive
#  notes::            free-form notes
#
class Sequence < AbstractModel
  belongs_to :observation
  belongs_to :user

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

  protected

  validates :locus, :observation, :user, presence: true
  validate  :bases_or_deposit
  validate  :unique_bases_for_obs
  validate  :unique_accession_for_obs

  def bases_or_deposit
    return if bases.present? || archive.present? && accession.present?
    errors.add(:bases, :validate_sequence_bases_or_archive.t)
  end

  def unique_bases_for_obs
    return if bases.blank?
    return unless other_sequences_same_obs.any? do |sequence|
      sequence.bases == bases
    end

    errors.add(:bases, :validate_sequence_bases_unique.t)
  end

  def unique_accession_for_obs
    return if accession.blank?
    return unless other_sequences_same_obs.any? do |sequence|
      sequence.accession == accession
    end

    errors.add(:bases, :validate_sequence_accession_unique.t)
  end

  # return array of other Sequences in same Observation, or nil if none
  def other_sequences_same_obs
    observation.try(:sequences) ? observation.sequences - [self] : nil
  end
end
