# frozen_string_literal: true

module Views::Controllers::GlossaryTerms
  module Versions
    # Past-version display for a glossary term. Two-column layout:
    # the version's `Term` summary on the left, `Versions::Table` on
    # the right, then a shared `VersionsFooter`. Converted from
    # `glossary_terms/versions/show.html.erb`.
    class Show < Views::Base
      prop :glossary_term, ::GlossaryTerm
      prop :versions, _Array(::GlossaryTerm::Version)

      def view_template
        add_page_title(
          :show_past_glossary_term_title.t(
            num: @glossary_term.version, name: @glossary_term.name
          )
        )
        add_context_nav(
          ::Tab::GlossaryTerm::VersionActions.new(term: @glossary_term)
        )
        container_class(:wide)
        column_classes(:six)

        render_main_row
        render(::Views::Layouts::VersionsFooter.new(
                 user: current_user,
                 obj: @glossary_term,
                 versions: @versions.to_a
               ))
      end

      private

      def render_main_row
        div(class: "row") do
          div(class: content_for(:left_columns)) do
            render(Term.new(glossary_term: @glossary_term))
          end
          div(class: content_for(:right_columns)) do
            render(::Views::Controllers::Versions::Table.new(
                     obj: @glossary_term, versions: @versions.to_a
                   ))
          end
        end
      end
    end
  end
end
