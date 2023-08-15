# frozen_string_literal: true

module Tabs
  module AuthorsHelper
    def author_review_links(obj:)
      [
        show_parent_link(obj),
        show_object_link(obj)
      ]
    end
  end
end
