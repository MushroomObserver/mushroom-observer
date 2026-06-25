# frozen_string_literal: true

# External link to the sequence's archived accession (GenBank, etc.).
class Tab::Sequence::Archive < Tab::Base
  def initialize(sequence:)
    super()
    @sequence = sequence
  end

  def title
    :show_observation_archive_link.t
  end

  def path
    @sequence.accession_url
  end

  def html_options
    { external: true }
  end

  def model
    @sequence
  end
end
