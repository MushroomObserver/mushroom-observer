# frozen_string_literal: true

# External link to BLAST the sequence on NCBI.
class Tab::Sequence::Blast < Tab::Base
  def initialize(sequence:)
    super()
    @sequence = sequence
  end

  def title
    :show_observation_blast_link.t
  end

  def path
    @sequence.blast_url
  end

  def html_options
    { external: true }
  end

  def model
    @sequence
  end
end
