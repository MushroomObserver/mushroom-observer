# frozen_string_literal: true

# Shared `Html`/`Text` view_template for the "standard" mailer shape
# (issue #4676's ERB -> Phlex conversion): an intro sentence, an
# always-shown boxed quoted message, a handy_links sentence, a links
# list, and a report-abuse footer. This is the single most common
# shape among the old ERB templates (AuthorMailer, ObserverQuestion,
# UserQuestion, CommercialInquiry, ProjectAdminRequest,
# NamingObserver, ...).
#
# Include into both the `Html` and `Text` subclasses of a mailer's
# `Build` class (named exactly that — `Views::Mailers::Base#html?`
# derives its answer from the class name). The including class must
# define `intro`, `handy_links`, and `links` (see
# `Views::Mailers::AuthorMailer::Html` for the reference shape).
# `message` defaults to `@message` (the common case, matching
# the standardized `prop :message` name every converted mailer uses
# for its quoted-content prop) — override it when the message needs
# computing (see `Views::Mailers::NamingObserverMailer::Build`). A
# mailer that deviates from this exact structure (conditional box, no
# report_abuse, extra fields, ...) should NOT force-fit this module —
# write its own view_template.
module Views::Mailers::StandardMessageBody
  def view_template
    return render_content unless html?

    render(Views::Layouts::Mailer::Html.new(subject: @subject)) do
      render_content
    end
  end

  private

  def message = @message

  def render_content
    emit_tp(intro)
    render_quoted_message
    emit_tp(handy_links)
    render_links
    emit_tp(report_abuse)
  end

  def render_quoted_message
    if html?
      render_message_box { trusted_html(message.tp) }
    else
      gap
      trusted_html(message.tp.html_to_ascii)
      divider
    end
  end

  def render_links
    return render_links_section(links) if html?

    gap
    render_links_section(links)
    plain("\n")
  end
end
