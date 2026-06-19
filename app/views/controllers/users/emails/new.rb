# frozen_string_literal: true

module Views::Controllers::Users
  module Emails
    # "Ask a User a Question" page.
    class New < Views::FullPageBase
      prop :target, ::User

      def view_template
        add_page_title(:ask_user_question_title.t(user: @target.legal_name))
        render(Form.new(target: @target, local: true))
      end
    end
  end
end
