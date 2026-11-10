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
      container_class(:text_image)
      add_index_title(@query)
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)

      render_filter_form
      PaginatedResults { render_list }
    end

    private

    # The visible input itself carries the submitted `name_has` param
    # -- not just a hidden id field -- so typed-but-unselected text
    # still filters (Sequence.name_has matches it as a text_name
    # substring). The autocompleter JS sets the visible value to the
    # matched name's text on selection (base_controller.js#selectRow
    # -> setSearchToken), so a selection submits that exact text
    # instead of an id, and still matches via the same substring
    # scope.
    def render_filter_form
      name_field = Components::ApplicationForm::FieldProxy.new(
        nil, "name_has", filtered_name_text
      )
      ContentPadded do
        IndexFilter(to: sequences_path, submit_text: :filter.ti) do
          render(Components::ApplicationForm::AutocompleterField.new(
                   name_field,
                   type: :name,
                   wrapper_options: { label: :sequence_filter_by,
                                      inline: true },
                   attributes: { size: 60, class: "mb-0" }
                 ))
        end
      end
    end

    # The submitted value is already display text (either typed, or
    # the exact name the autocompleter filled in on selection) -- no
    # Name lookup needed to redisplay it in the field.
    def filtered_name_text
      @query&.params&.dig(:name_has).to_s
    end

    def render_list
      ListGroup do |list|
        @sequences.each do |seq|
          list.item(class: "d-flex align-items-start") { render_row(seq) }
        end
      end
    end

    def render_row(seq)
      div(class: "id-badge-col") { IDBadge(object: seq, size: :lg) }
      div(class: "flex-grow-1") do
        render_obs_link(seq)
        render_meta(seq)
      end
    end

    def render_obs_link(seq)
      obs_name = viewer_aware_unique_format_name(seq.observation).t
      Link(type: :get, name: obs_name,
           target: seq.observation.show_link_args) do
        trusted_html(obs_name)
      end
    end

    def render_meta(seq)
      div do
        Link(type: :get, name: seq.format_name, target: seq.show_link_args)
        whitespace
        small { plain(seq.created_at.web_time) }
        plain(": ")
        Link(type: :user, user: seq.user)
      end
      render_deposit_line(seq) if seq.deposit?
    end

    def render_deposit_line(seq)
      div do
        render_archive_link(seq)
        plain(": ")
        render_accession_link(seq)
      end
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
