# frozen_string_literal: true

# Shared `Html`/`Text` view_template for the second most common mailer
# shape (issue #4676's ERB -> Phlex conversion): an intro sentence, a
# `*Label:* value` fields block, a handy_links sentence, and a links
# list — no boxed quoted message, no report-abuse footer (unlike
# `Views::Mailers::StandardMessageBody`). Confirmed identical shape in
# ConsensusChangeMailer and NameProposalMailer.
#
# Include alongside `Views::Mailers::CommonSections`. The including
# class must define `html?`, `intro`, `fields`, `handy_links`, and
# `links`. Don't force-fit a mailer whose blank-line spacing differs
# from this exact sequence (e.g. OccurrenceChangeMailer has no blank
# line between fields and handy_links in text mode) — write its own
# view_template instead; verify against its fixture via the parity
# test either way.
module Views::Mailers::FieldsOnlyBody
  def view_template
    return render_content unless html?

    render(Views::Layouts::Mailer::Html.new(subject: @subject)) do
      render_content
    end
  end

  private

  def render_content
    emit_tp(intro)
    gap
    emit_tp(fields)
    gap
    emit_tp(handy_links)
    render_links
  end

  # HTML mode needs no explicit gap — block-level tags need nothing
  # but insignificant whitespace between them. Text mode needs an
  # explicit blank line, matching the ERB templates' blank source
  # lines between `<%= fields.tp.html_to_ascii %>` and the next tag.
  def gap
    plain("\n\n") unless html?
  end

  def render_links
    return render_links_section(links) if html?

    plain("\n\n")
    render_links_section(links)
    plain("\n")
  end
end
