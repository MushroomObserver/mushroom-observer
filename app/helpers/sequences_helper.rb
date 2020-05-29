# helpers for add Sequence view
module SequencesHelper
  def sequence_accession_link(sequence)
    link_to(truncate(sequence.accession, length: sequence.locus_width / 2).t,
            sequence.accession_url, target: "_blank", rel: "noopener")
  end

  def sequence_archive_link(sequence)
    url = WebSequenceArchive.archive_home(sequence.archive)
    link_to(sequence.archive.t, url, target: "_blank", rel: "noopener")
  end

  # dropdown list for create_sequence
  def archive_dropdown
    WebSequenceArchive.archives.each_with_object([]) do |archive, array|
      # append array which repeats archive[:name] twice
      array << Array.new(2, archive[:name])
    end
  end
end
