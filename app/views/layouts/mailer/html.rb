# frozen_string_literal: true

# The one piece of markup genuinely common to every HTML mailer body
# (issue #4676's ERB -> Phlex conversion): the outer
# `<html><head><title>...</head><body>...</body></html>` document
# wrapper, since there's no ActionMailer layout today and each old
# ERB template built this by hand. NOT a place for the
# links-list/report-abuse footer — those are genuinely optional
# per-mailer content (several mailers have no links list at all), so
# they stay in `Views::Mailers::CommonSections`, called explicitly by
# whichever mailer views actually have that content.
class Views::Layouts::Mailer::Html < Views::Mailers::Base
  prop :subject, ::String

  def view_template(&block)
    html do
      head { title { "#{:app_title.t}: #{@subject}" } }
      # topmargin/leftmargin/etc + the leading/trailing <br> are
      # legacy spacing hacks for old email clients, carried over
      # verbatim from the ERB templates.
      body(topmargin: "0", leftmargin: "0", rightmargin: "0",
           bottommargin: "0") do
        br
        yield
        br
      end
    end
  end
end
