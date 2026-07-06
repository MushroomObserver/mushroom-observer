# frozen_string_literal: true

module Views::Controllers::Sequences
  # Paginated list of Sequence rows — each item links to the sequence
  # + its observation, optionally to the GenBank archive + accession,
  # and is footed with creator + timestamp.
  class Index < Views::FullPageBase
    prop :query, ::Query
    prop :sequences, _Array(::Sequence)
    prop :pagination_data, ::PaginationData

    def view_template
      add_index_title(@query)
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)

      PaginatedResults { render_list }
    end

    private

    def render_list
      ListGroup do |list|
        @sequences.each { |seq| list.item { render_row(seq) } }
      end
    end

    def render_row(seq)
      render_top_links(seq)
      render_deposit_line(seq) if seq.deposit?
      small { plain(seq.created_at.web_time) }
      plain(": ")
      Link(type: :user, user: seq.user)
    end

    def render_top_links(seq)
      link_to(seq.unique_format_name, seq.show_link_args)
      br
      link_to(seq.observation.show_link_args) do
        trusted_html(viewer_aware_unique_format_name(seq.observation).t)
      end
      br
    end

    def render_deposit_line(seq)
      render_archive_link(seq)
      plain(": ")
      render_accession_link(seq)
      br
    end

    def render_archive_link(seq)
      url = ::WebSequenceArchive.archive_home(seq.archive)
      Link(type: :external, content: seq.archive.t, path: url)
    end

    def render_accession_link(seq)
      Link(type: :external,
           content: truncate(seq.accession,
                             length: seq.locus_width / 2).t,
           path: seq.accession_url)
    end
  end
end
