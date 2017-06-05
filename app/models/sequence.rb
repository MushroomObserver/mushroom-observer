#  = Sequence Model
#
#  A nucleotide sequence associated with an Observation.
#  A Sequence must have: a Locus, either Bases and/or (Archive and Accession).
#  It may have Notes.
#
#  == Attributes
#
#  id::               unique numerical id, starting at 1.
#  observation_id::   id of the associated Observation
#  locus::            description of the locus
#  bases::            nucleotides
#  archive::          on-line database to which the sequence was submitted
#  accession::        accession # in the Archive
#  notes::
#
class Sequence < AbstractModel
  belongs_to :observation
end
