# frozen_string_literal: true

# Webmaster question email body. Always plain text regardless of the
# recipient's email_html preference (see WebmasterMailer#build's
# `content_style: "plain"`), so there's no Html/Text split here —
# `question` is arbitrary user-submitted text, emitted verbatim via
# `trusted_text` since a text/plain body has no markup to escape for.
class Views::Mailers::WebmasterMailer::Build < Views::Mailers::Base
  prop :question, ::String

  def view_template
    trusted_text(@question)
  end
end
