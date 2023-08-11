# frozen_string_literal: true

module Tabs
  module AuthorsHelper
    def author_review_links(obj:)
      [
        [:show_object.t(type: obj.parent.type_tag),
         obj.parent.show_link_args,
         { class: "show_parent_link" }],
        [:show_object.t(type: type),
         obj.show_link_args,
         { class: "show_object_link" }]
      ]
    end
  end
end
