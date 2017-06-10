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
end
