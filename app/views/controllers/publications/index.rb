# frozen_string_literal: true

module Views::Controllers::Publications
  # Publications index — intro/citation block + striped table of all
  # publications with peer-review and MO-mentioned flags + admin
  # edit/destroy links.
  class Index < Views::FullPageBase
    prop :query, ::Query
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::Publication)

    # Counts are over the full query result set, not just the
    # current page's `@objects`.
    def full_count
      @full_count ||= @query.num_results
    end

    def peer_count
      @peer_count ||= @query.results.count(&:peer_reviewed)
    end

    def mo_count
      @mo_count ||= @query.results.count(&:mo_mentioned)
    end

    INTRO_CITATION_URL =
      "http://www.mykoweb.com/articles/Web%20Watch--Mushroom%20Observer.pdf"
    INTRO_CITATION_TEXT =
      'Wood, Michael (Summer 2008). "WebWatch: Observing Mushrooms". ' \
      "Fungi Magazine 1 (2)."

    def view_template
      add_index_title(@query)
      add_context_nav(::Tab::Publication::IndexActions.new)
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)
      container_class(:wide)

      Container(width: :text) { render_intro }
      PaginatedResults { render_publications_table }
      ContentPadded do
        trusted_html(:publication_legend.tp)
      end
    end

    private

    def render_intro
      ContentPadded do
        trusted_html(:publication_index_intro.tp)
        trusted_html(:publication_citation.tp)
        a(href: INTRO_CITATION_URL) { plain(INTRO_CITATION_TEXT) }
      end
    end

    def render_publications_table
      Table(@objects,
            variant: :striped, identifier: "publications",
            class: "mb-3 mt-3") do |tbl|
        add_full_link_column(tbl)
        tbl.column(:publication_link.l) { |pub| link_cell(pub) }
        tbl.column("(#{peer_count})", align: :center) do |pub|
          pub.peer_reviewed ? "P" : ""
        end
        tbl.column("(#{mo_count})", align: :center) do |pub|
          pub.mo_mentioned ? "M" : ""
        end
        tbl.column("", align: :center) { |pub| admin_cell(pub) }
      end
    end

    def add_full_link_column(tbl)
      tbl.column("#{:publication_full.l} (#{full_count})") do |pub|
        full_text = pub.full.t.strip_links
        Link(type: :get, name: full_text, target: pub) do
          trusted_html(full_text)
        end
      end
    end

    def link_cell(pub)
      return "" unless pub.link

      str = pub.link.sub(%r{^.*://+}, "").sub(%r{(/|\?).*}, "")
      capture do
        Link(type: :get, name: str, target: pub.link, title: pub.link,
             data: { tooltip_target: "tip" })
      end
    end

    def admin_cell(pub)
      capture do
        InlineCRUDLinks(target: pub, user: current_user)
      end
    end
  end
end
