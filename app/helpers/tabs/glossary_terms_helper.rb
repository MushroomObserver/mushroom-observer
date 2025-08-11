# frozen_string_literal: true

module Tabs
  module GlossaryTermsHelper
    def glossary_term_form_new_tabs
      [
        # Replace this link with a "Cancel" link (back to glossary)
        # See https://www.pivotaltracker.com/story/show/174614188
        glossary_terms_index_tab
      ]
    end

    def glossary_term_form_edit_tabs(term:)
      [
        # Replace these two links with a "Cancel" link
        # See https://www.pivotaltracker.com/story/show/174614188
        glossary_term_return_tab(term),
        glossary_terms_index_tab
      ]
    end

    def glossary_term_image_form_tabs(term:)
      [
        glossary_term_return_tab(term),
        edit_glossary_term_tab(term)
      ]
    end

    def glossary_term_version_tabs(term:)
      [show_glossary_term_tab(term)]
    end

    def show_glossary_term_tab(term)
      InternalLink::Model.new(
        :show_glossary_term.t(glossary_term: term.name), term,
        glossary_term_path(term.id)
      ).tab
    end

    def glossary_term_return_tab(term)
      InternalLink::Model.new(
        :cancel_and_show.t(type: :glossary_term), term,
        glossary_term_path(term.id)
      ).tab
    end

    def destroy_glossary_term_tab(term)
      InternalLink::Model.new(
        :destroy_object.t(type: :glossary_term), term, term,
        html_options: { button: :destroy }
      ).tab
    end

    def glossary_terms_index_tab
      InternalLink::Model.new(
        :glossary_term_index.t, GlossaryTerm,
        glossary_terms_path
      ).tab
    end

    def new_glossary_term_tab
      InternalLink::Model.new(
        :create_glossary_term.t, GlossaryTerm,
        new_glossary_term_path
      ).tab
    end

    def edit_glossary_term_tab(term)
      InternalLink::Model.new(
        :edit_glossary_term.t, term,
        edit_glossary_term_path(term.id)
      ).tab
    end
  end
end
