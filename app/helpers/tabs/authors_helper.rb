# frozen_string_literal: true

module Tabs
  module AuthorsHelper
    def author_review_tabs(obj:)
      [
        show_parent_tab(obj),
        show_object_tab(obj)
      ]
    end
  end
end
