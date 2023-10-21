# frozen_string_literal: true

module Tabs
  module GlossaryTermsHelper
    def glossary_term_show_tabs(term:, user:)
      return [] unless user

      links = [
        glossary_terms_index_tab,
        new_glossary_term_tab,
        edit_glossary_term_tab(term)
      ]
      links << destroy_glossary_term_tab(term) if in_admin_mode?
      links
    end

    def glossary_term_index_tabs
      [new_glossary_term_tab]
    end

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
      [:show_glossary_term.t(glossary_term: term.name),
       glossary_term_path(term.id),
       { class: tab_id(__method__.to_s) }]
    end

    def glossary_term_return_tab(term)
      [:cancel_and_show.t(type: :glossary_term),
       glossary_term_path(term.id),
       { class: tab_id(__method__.to_s) }]
    end

    def destroy_glossary_term_tab(term)
      [nil, term, { button: :destroy }]
    end

    def glossary_terms_index_tab
      [:glossary_term_index.t, glossary_terms_path,
       { class: tab_id(__method__.to_s) }]
    end

    def new_glossary_term_tab
      [:create_glossary_term.t, new_glossary_term_path,
       { class: tab_id(__method__.to_s) }]
    end

    def edit_glossary_term_tab(term)
      [:edit_glossary_term.t, edit_glossary_term_path(term.id),
       { class: tab_id(__method__.to_s) }]
    end
  end
end
