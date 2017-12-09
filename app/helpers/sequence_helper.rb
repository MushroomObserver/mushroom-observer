# helpers for add Sequence view
module SequenceHelper
  def show_sequence_right_tabs(sequence)
    tabs = [
      link_with_query(:cancel_and_show.t(type: :observation),
                      sequence.observation.show_link_args)
    ]
    return tabs unless check_permission(sequence)
    tabs.push(link_with_query(:EDIT.t, sequence.edit_link_args)).
      push(link_with_query(:DESTROY.t, sequence.destroy_link_args))
  end

  def sequence_accession_link(sequence)
    link_to(truncate(sequence.accession, length: sequence.locus_width / 2).t,
            sequence.accession_url, target: "_blank")
  end

  def sequence_archive_link(sequence)
    url = WebSequenceArchive.archive_home(sequence.archive)
    link_to(sequence.archive.t, url, target: "_blank")
  end

  # dropdown list for add_sequence
  def archive_dropdown
    WebSequenceArchive.archives.each_with_object([]) do |archive, array|
      # append array which repeats archive[:name] twice
      array << Array.new(2, archive[:name])
    end
  end
end
