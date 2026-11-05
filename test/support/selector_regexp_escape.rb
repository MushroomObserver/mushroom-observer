# frozen_string_literal: true

# Nokogiri >= 1.19.5 applies CSS escapes inside a custom pseudo-class's
# string argument, but rails-dom-testing 2.3.0 substitutes a Regexp into
# `:match('attr', ?)` unescaped, so `\d` arrives in the XPath as a
# carriage return. Escaping `\` and `"` hands nokogiri the regex source
# intact. Remove once rails-dom-testing escapes it upstream.
module SelectorRegexpEscape
  private

  def matcher_for(value, format_for_presentation)
    return super if format_for_presentation || !value.is_a?(Regexp)

    "\"#{value.to_s.gsub(/[\\"]/) { |char| "\\#{char}" }}\""
  end
end

module Rails::Dom::Testing::Assertions::SelectorAssertions
  SubstitutionContext.prepend(SelectorRegexpEscape)
end
