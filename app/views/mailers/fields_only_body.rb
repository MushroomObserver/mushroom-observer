# frozen_string_literal: true

# Shared `Html`/`Text` view_template for the second most common mailer
# shape: an intro sentence, a `*Label:* value` fields block, a
# handy_links sentence, and a links list — no boxed quoted message,
# no report-abuse footer (unlike `Views::Mailers::StandardMessageBody`).
# Used by ConsensusChangeMailer, NameProposalMailer, and
# OccurrenceChangeMailer.
#
# Include into a mailer's `Html`/`Text` classes (named exactly that —
# `Views::Mailers::Base#html?` derives its answer from the class
# name). The including class must define `intro`, `fields`,
# `handy_links`, and `links`. Exact text-mode blank-line placement
# isn't worth preserving byte-for-byte against a mailer's previous
# output — use this module's fixed spacing even where it differs
# slightly.
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

  def render_links
    return render_links_section(links) if html?

    gap
    render_links_section(links)
    newline
  end
end
