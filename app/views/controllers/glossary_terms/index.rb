# frozen_string_literal: true

module Views::Controllers::GlossaryTerms
  # Paginated glossary terms index. Page chrome +
  # a `Components::ListGroup::Base` of one `Index::Item` per term.
  class Index < Views::FullPageBase
    prop :query, ::Query
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::GlossaryTerm)

    def view_template
      add_page_title(:glossary_term_index_title.t)
      add_pagination(@pagination_data)
      container_class(:text_image)

      content_for(:filters) { documentation_link }

      PaginatedResults { render_list }
    end

    private

    def documentation_link
      link_to(
        :glossary_term_index_documentation.tp,
        "https://github.com/MushroomObserver/mushroom-observer/" \
        "blob/main/doc/glossary.md"
      )
    end

    def render_list
      render(::Components::ListGroup::Base.new) do |list|
        @objects.each do |term|
          list.item { render(Item.new(glossary_term: term)) }
        end
      end
    end
  end
end
