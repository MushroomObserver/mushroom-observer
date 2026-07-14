# frozen_string_literal: true

module Views::Controllers::Publications
  # Publications index — intro/citation block + striped table of all
  # publications with peer-review and MO-mentioned flags + admin
  # edit/destroy links.
  class Index < Views::FullPageBase
    prop :query, _Nilable(::Query), default: nil
    prop :publications, _Array(::Publication)

    def full_count
      @full_count ||= @publications.length
    end

    def peer_count
      @peer_count ||= @publications.count(&:peer_reviewed)
    end

    def mo_count
      @mo_count ||= @publications.count(&:mo_mentioned)
    end

    INTRO_CITATION_URL =
      "http://www.mykoweb.com/articles/Web%20Watch--Mushroom%20Observer.pdf"
    INTRO_CITATION_TEXT =
      'Wood, Michael (Summer 2008). "WebWatch: Observing Mushrooms". ' \
      "Fungi Magazine 1 (2)."

    def view_template
      add_index_title(@query)
      add_context_nav(::Tab::Publication::IndexActions.new)
      container_class(:wide)

      Container(width: :text) { render_intro }
      render_publications_table
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
      Table(@publications,
            variant: :striped, identifier: "publications",
            class: "mb-3 mt-3") do |tbl|
        add_full_link_column(tbl)
        tbl.column(:publication_link.l) { |pub| link_cell(pub) }
        tbl.column("(#{peer_count})") { |pub| pub.peer_reviewed ? "P" : "" }
        tbl.column("(#{mo_count})") { |pub| pub.mo_mentioned ? "M" : "" }
        tbl.column("") { |pub| admin_cell(pub) }
      end
    end

    def add_full_link_column(tbl)
      tbl.column("#{:publication_full.l} (#{full_count})") do |pub|
        link_to(pub) { trusted_html(pub.full.t.strip_links) }
      end
    end

    def link_cell(pub)
      return "" unless pub.link

      str = pub.link.sub(%r{^.*://+}, "").sub(%r{(/|\?).*}, "")
      capture do
        link_to(str, pub.link, title: pub.link, data: { toggle: "tooltip" })
      end
    end

    def admin_cell(pub)
      return "" unless in_admin_mode? || pub.can_edit?(current_user)

      capture do
        link_to(:EDIT.l, edit_publication_path(pub))
        whitespace
        link_to(:DESTROY.l, { action: :destroy, id: pub.id },
                data: { confirm: :are_you_sure.t })
      end
    end
  end
end
