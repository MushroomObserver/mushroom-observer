# frozen_string_literal: true

module Views::Controllers::Support
  # Thanks page (post-donation).
  class Thanks < Views::FullPageBase
    def view_template
      add_page_title(:thanks_title.l)
      add_context_nav(::Tab::Support::GovernanceActions.new)

      trusted_html(:thanks_note.tp)
    end
  end
end
