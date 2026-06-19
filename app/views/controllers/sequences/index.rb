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

      paginated_results { render_list }
    end

    private

    def render_list
      render(::Components::ListGroup::Base.new) do |list|
        @sequences.each { |seq| list.item { render_row(seq) } }
      end
    end

    def render_row(seq)
      render_top_links(seq)
      render_deposit_line(seq) if seq.deposit?
      small { plain(seq.created_at.web_time) }
      plain(": ")
      render(::Components::Link::Object::User.new(user: seq.user))
    end

    def render_top_links(seq)
      link_to(seq.unique_format_name, seq.show_link_args)
      br
      link_to(seq.observation.show_link_args) do
        trusted_html(seq.observation.unique_format_name.t)
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
      link_to(seq.archive.t, url, target: "_blank", rel: "noopener")
    end

    def render_accession_link(seq)
      link_to(truncate(seq.accession, length: seq.locus_width / 2).t,
              seq.accession_url, target: "_blank", rel: "noopener")
    end
  end
end
