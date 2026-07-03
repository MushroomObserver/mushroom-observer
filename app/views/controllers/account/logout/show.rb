# frozen_string_literal: true

module Views::Controllers::Account::Logout
  class Show < Views::FullPageBase
    def view_template
      add_page_title(:logout_title.t)
      trusted_html(:logout_note.tp)
    end
  end
end
