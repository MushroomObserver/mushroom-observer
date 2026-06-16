# frozen_string_literal: true

module Views::Controllers::Support
  # Open letter (governance area).
  class Letter < Views::Base
    def view_template
      add_page_title(:letter_title.l)
      add_context_nav(::Tab::Support::GovernanceActions.new)

      trusted_html(:letter_body.tp)
    end
  end
end
