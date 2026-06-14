# frozen_string_literal: true

# Mixin for safely rendering HTML content in Phlex components and
# views. Include to get the `trusted_html` method.
#
# Lives under `Phlex::` (in `app/helpers/phlex/`) rather than inside
# `app/components/` or `app/views/` because the implementation uses
# `raw(...)` and `.html_safe`. The on-save guard hook
# (`.claude/hooks/check_any_phlex_props_on_save.sh`) blocks those
# patterns inside the `app/components/` and `app/views/` trees;
# moving the mixin out lets the implementation use the escape hatch
# while still keeping callers in actual Phlex views away from `raw`
# / `.html_safe`. The two helpers used in the body (`raw` and
# `plain`) are both Phlex helpers, which is why the `Phlex::`
# namespace fits.
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
  end
end
