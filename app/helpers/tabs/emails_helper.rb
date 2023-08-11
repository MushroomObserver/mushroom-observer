# frozen_string_literal: true

module Tabs
  module EmailsHelper
    def email_name_change_request_links(name:)
      [object_return_link(name)]
    end

    def email_merge_request_links(model:, old_obj:)
      [[:cancel_and_show.t(type: model.type_tag),
        add_query_param(old_obj.show_link_args),
        { class: "#{model.type_tag}_return_link" }]]
    end
  end
end
