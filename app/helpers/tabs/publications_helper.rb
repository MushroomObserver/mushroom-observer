# frozen_string_literal: true

module Tabs
  module PublicationsHelper
    def publication_show_links(pub:, user:)
      links = [
        new_publication_link,
        publications_index_link
      ]
      return links unless in_admin_mode? || pub.can_edit?(user)

      links += publication_mod_links(pub)
      links
    end

    def publications_index_links
      [new_publication_link]
    end

    def publication_form_new_links
      [publications_index_link]
    end

    def publication_form_edit_links(pub:)
      [
        object_return_link(pub),
        publications_index_link
      ]
    end

    def new_publication_link
      [:create_publication.t, new_publication_path,
       { class: __method__.to_s }]
    end

    def publications_index_link
      [:publication_index.t, publications_path,
       { class: __method__.to_s }]
    end

    def publication_mod_links(pub)
      [
        edit_publication_link(pub),
        destroy_publication_link(pub)
      ]
    end

    def edit_publication_link(pub)
      [:EDIT.t, edit_publication_path(pub.id),
       { class: __method__.to_s }]
    end

    def destroy_publication_link(pub)
      [nil, pub, { button: :destroy }]
    end
  end
end
