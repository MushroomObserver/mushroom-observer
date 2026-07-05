# frozen_string_literal: true

# Mixin for safely rendering HTML content in Phlex components and
# views. Include to get the `trusted_html` method.
#
# Lives under `Phlex::` (in `app/helpers/phlex/`) rather than inside
# `app/components/` or `app/views/` because the implementation uses
# `raw(...)`. The on-save guard hook
# (`.claude/hooks/check_any_phlex_props_on_save.sh`) blocks `raw`
# (and `.html_safe`) inside the `app/components/` and `app/views/`
# trees; moving the mixin out lets the implementation use the
# escape hatch while still keeping callers in actual Phlex views
# away from those patterns. The two helpers used in the body
# (`raw` and `plain`) are both Phlex helpers, which is why the
# `Phlex::` namespace fits.
#
# @example
#   class MyComponent < Phlex::HTML
#     include Phlex::TrustedHtml
#
#     def view_template
#       trusted_html(:some_translation.l)
#     end
#   end
module Phlex
  module TrustedHtml
    # Render content that may contain HTML markup from trusted
    # sources. If content is already html_safe, renders as raw HTML.
    # Otherwise, escapes and outputs as plain text.
    #
    # Do NOT use for user-generated content.
    #
    # @param content [ActiveSupport::SafeBuffer, String] HTML content
    # @return [void]
    def trusted_html(content)
      if content.is_a?(ActiveSupport::SafeBuffer)
        raw(content) # rubocop:disable Rails/OutputSafety
      else
        plain(content.to_s)
      end
    end

    # Emits `content` verbatim, with no HTML-escaping, regardless of
    # its safety flag. Only for buffers that are never parsed as
    # HTML — namely a mailer's plain-text body — where there is no
    # markup to inject into and a literal `&`/`<` (in a URL, a raw
    # user message) must reach the reader unchanged. Using
    # `trusted_html` there would wrongly HTML-escape ordinary
    # characters, since it treats an un-flagged String as untrusted.
    #
    # Do NOT use this for HTML output — it bypasses escaping
    # unconditionally.
    def trusted_text(content)
      raw(content.to_s.html_safe) # rubocop:disable Rails/OutputSafety
    end
  end
end
