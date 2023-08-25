# frozen_string_literal: true

module Tabs
  module EmailsHelper
    def email_name_change_request_tabs(name:)
      [object_return_tab(name)]
    end

    def email_merge_request_tabs(old_obj:)
      [object_return_tab(old_obj)]
    end
  end
end
