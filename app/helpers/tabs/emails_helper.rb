# frozen_string_literal: true

module Tabs
  module EmailsHelper
    def email_name_change_request_links(name:)
      [object_return_link(name)]
    end

    def email_merge_request_links(model:, old_obj:)
      [object_return_link(old_obj)]
    end
  end
end
