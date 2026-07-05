# frozen_string_literal: true

module Views::Mailers::ApprovalMailer
  # Admins sending approval of a user's request. Always plain
  # ASCII-ified text regardless of the recipient's email_html
  # preference — a single Build class, no Html/Text split.
  class Build < Views::Mailers::Base
    prop :message, ::String

    def view_template
      trusted_html(@message.tp.html_to_ascii)
    end
  end
end
