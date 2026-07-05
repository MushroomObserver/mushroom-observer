# frozen_string_literal: true

# Shared rendering toolkit mixed into every mailer's `Html`/`Text`
# view (issue #4676's ERB -> Phlex conversion). Extracted from the
# byte-identical boilerplate duplicated across the old ERB templates:
# a `links` list of `[label, url]` pairs, a boxed quoted-message div,
# and the report-abuse footer line. Each including class defines
# `html?` so these methods know which body they're building; the
# `intro`/`fields`/`handy_links` composition stays per-mailer since it
# varies too much to share further.
#
# `label`s passed in here are expected to already be `.t`/`.tp`'d
# (i.e. real ActiveSupport::SafeBuffer, per Textile's `_safe`
# variants) — `emit_tp`/`render_links_section` just decide whether to
# emit them as HTML or convert them to ASCII first. Raw, un-textilized
# strings (URLs, arbitrary user text) go through `trusted_text`, which
# emits verbatim with no escaping — correct for a text/plain body,
# where there's no markup to protect and an ordinary `&`/`<` must
# reach the reader unchanged. Using `trusted_html` for those would
# incorrectly HTML-escape them, since it treats an un-flagged String
# as untrusted and falls back to `plain` (which always escapes).
module Views::Mailers::CommonSections
  private

  # Blank-line separator between sections in text mode; a no-op in
  # HTML mode — block-level tags need nothing but insignificant
  # whitespace between them (the old ERB templates' literal blank
  # source lines only matter for the plain-text body).
  def gap
    plain("\n\n") unless html?
  end

  # A single newline — shorthand for the common "end this text line"
  # call, used unconditionally (always inside an already text-mode-
  # only branch, unlike `gap`).
  def newline
    plain("\n")
  end

  # Just the "--------------------------------------------------"
  # line itself, no surrounding blank lines — for callers whose
  # spacing around it isn't the fixed symmetric shape `divider`
  # assumes (see LocationChangeMailer's per-field dashes).
  def dashes_line
    plain("#{"-" * 50}\n")
  end

  # The 50-dash horizontal rule separating quoted content from the
  # footer in a text-mode body, blank-line-padded on both sides —
  # matches the old ERB templates' literal
  # "--------------------------------------------------" line.
  def divider
    gap
    dashes_line
    newline
  end

  # Outputs an already `.tp`-textilized string in the current mode.
  def emit_tp(str)
    if html?
      trusted_html(str.tp)
    else
      trusted_html(str.tp.html_to_ascii)
    end
  end

  def render_links_section(links)
    return if links.blank?

    html? ? render_links_section_html(links) : render_links_section_text(links)
  end

  def render_links_section_html(links)
    ul(type: "none") do
      links.each do |label, url|
        li do
          trusted_html(label)
          plain(": ")
          a(href: url) { url }
        end
      end
    end
  end

  def render_links_section_text(links)
    links.each do |label, url|
      trusted_html(label.html_to_ascii)
      plain(": ")
      trusted_text(url)
      newline
    end
  end

  def render_message_box(&block)
    if html?
      div(style: "margin-left:20px; margin-right:20px; " \
                  "padding-left:20px; padding-right:20px; " \
                  "padding-top:10px; padding-bottom:10px; " \
                  "border:1px dotted; background:#E0E0E0; " \
                  "color:#000000;", &block)
    else
      yield
      newline
    end
  end

  def report_abuse
    :email_report_abuse.l(email: MO.webmaster_email_address)
  end
end
