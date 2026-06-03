# frozen_string_literal: true

# NCBI Nucleotide external-site link for a Name. Uses name s.s.;
# including group gets 0 or few hits (only sequences whose notes
# happen to include the word "group").
class Tab::Name::NcbiNucleotide < Tab::Name::ExternalBase
  def title
    "NCBI Nucleotide"
  end

  def path
    "https://www.ncbi.nlm.nih.gov/nuccore/?term=#{@name.sensu_stricto}"
  end
end
