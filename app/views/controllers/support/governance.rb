# frozen_string_literal: true

module Views::Controllers::Support
  # Project governance page — static textile body.
  class Governance < Views::FullPageBase
    def view_template
      add_page_title(:governance_title.l)
      add_context_nav(::Tab::Support::GovernanceActions.new)

      trusted_html(:governance.tp)
    end
  end
end
