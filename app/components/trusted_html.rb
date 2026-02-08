# frozen_string_literal: true

# Shared helper for safely rendering HTML content in Phlex components.
# Include this module to get the `trusted_html` method.
#
# @example
#   class MyComponent < Phlex::HTML
#     include Components::TrustedHtml
#
#     def view_template
#       trusted_html(:some_translation.l)
#     end
#   end
#
module Components::TrustedHtml
  # Render content that may contain HTML markup from trusted sources.
  # If content is already html_safe, renders as raw HTML.
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
