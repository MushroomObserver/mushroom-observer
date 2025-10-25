# frozen_string_literal: true

module Tabs
  module PublicationsHelper
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
  end
end
