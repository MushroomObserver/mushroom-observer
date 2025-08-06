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
      InternalLink.new(:add_object.t(:PUBLICATION), new_publication_path).tab
    end

    def publications_index_tab
      InternalLink.new(:publication_index.t, publications_path).tab
    end

    def publication_mod_tabs(pub)
      [
        edit_publication_tab(pub),
        destroy_publication_tab(pub)
      ]
    end

    def edit_publication_tab(pub)
      InternalLink.new(:EDIT.t, edit_publication_path(pub.id)).tab
    end

    def destroy_publication_tab(pub)
      InternalLink::Model.new(:destroy_object.t(TYPE: Publication),
                              pub, pub,
                              html_options: { button: :destroy }).tab
    end
  end
end
