# frozen_string_literal: true

module Views::Controllers::Support
  # Annual wrap-up letter (2011).
  class Wrapup2011 < Views::Base
    def view_template
      add_page_title(:wrapup_2011_title.l)
      add_context_nav(::Tab::Support::GovernanceActions.new)

      trusted_html(:wrapup_2011_body.tp)
    end
  end
end
