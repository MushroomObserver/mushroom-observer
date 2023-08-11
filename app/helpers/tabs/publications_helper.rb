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
        publication_return_link(pub),
        publications_index_link
      ]
    end

    def new_publication_link
      [:create_publication.t, new_publication_path,
       { class: "new_publication_link" }]
    end

    def publications_index_link
      [:publication_index.t, publications_path,
       { class: "publications_index_link" }]
    end

    def publication_return_link(pub)
      [:cancel_and_show.t(type: :publication),
       add_query_param(pub.show_link_args),
       { class: "publication_return_link" }]
    end

    def publication_mod_links(pub)
      [
        [:EDIT.t, edit_publication_path(pub.id),
         { class: "edit_publication_link" }],
        [nil, pub, { button: :destroy }]
      ]
    end
  end
end
