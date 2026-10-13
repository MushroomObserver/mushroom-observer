# frozen_string_literal: true

# The one piece of markup common to every HTML mailer body: the
# outer `<html><head><title>...</head><body>...</body></html>`
# document wrapper, since there's no ActionMailer layout today. NOT a
# place for the links-list/report-abuse footer — those are optional
# per-mailer content (several mailers have no links list), so they
# stay in `Views::Mailers::CommonSections`, called explicitly by
# whichever mailer views have that content.
class Views::Layouts::Mailer::Html < Views::Mailers::Base
  prop :subject, ::String

  def view_template(&block)
    html do
      head { title { "#{:app_title.t}: #{@subject}" } }
      # topmargin/leftmargin/etc + the leading/trailing <br> are
      # legacy spacing hacks for old email clients.
      body(topmargin: "0", leftmargin: "0", rightmargin: "0",
           bottommargin: "0") do
        br
        yield
        br
      end
    end
  end
end
