# frozen_string_literal: true

module Views::Controllers::Support
  # Annual wrap-up letter (2012).
  class Wrapup2012 < Views::Base
    def view_template
      add_page_title(:wrapup_2012_title.l)
      add_context_nav(::Tab::Support::GovernanceActions.new)

      trusted_html(:wrapup_2012_body.tp)
    end
  end
end
