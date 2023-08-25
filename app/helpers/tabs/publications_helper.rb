# frozen_string_literal: true

module Tabs
  module PublicationsHelper
    def publication_show_tabs(pub:, user:)
      links = [
        new_publication_tab,
        publications_index_tab
      ]
      return links unless in_admin_mode? || pub.can_edit?(user)

      links += publication_mod_tabs(pub)
      links
    end

    def publications_index_tabs
      [new_publication_tab]
    end

    def publication_form_new_tabs
      [publications_index_tab]
    end

    def publication_form_edit_tabs(pub:)
      [
        object_return_tab(pub),
        publications_index_tab
      ]
    end

    def new_publication_tab
      [:create_publication.t, new_publication_path,
       { class: tab_id(__method__.to_s) }]
    end

    def publications_index_tab
      [:publication_index.t, publications_path,
       { class: tab_id(__method__.to_s) }]
    end

    def publication_mod_tabs(pub)
      [
        edit_publication_tab(pub),
        destroy_publication_tab(pub)
      ]
    end

    def edit_publication_tab(pub)
      [:EDIT.t, edit_publication_path(pub.id),
       { class: tab_id(__method__.to_s) }]
    end

    def destroy_publication_tab(pub)
      [nil, pub, { button: :destroy }]
    end
  end
end
