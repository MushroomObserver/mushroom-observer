# frozen_string_literal: true

#
#  = Check for Unsafe HTML
#
#  This file adds a little bit of code at the end of every get/post request
#  to ensure that no unsafe HTML has slipped by.
#
################################################################################

module CheckForUnsafeHtml
  def check_for_unsafe_html!
    return if @unsafe_html_filter_disabled

    str = @response.body.to_s.force_encoding("utf-8")
    return unless str[0..4] == "<!DOC"

    str.gsub!(/<!--.*?-->/mu, "")
    str.gsub!(/<!\[CDATA\[.*?\]\]>/mu, "")
    return unless str =~ /&lt;[a-z]+|&amp;[#\w]+;/i

    msg = "..." + $`[-200..] + "***HERE***" + $& + $'[0..200] + "..."
    flunk("Unsafe HTML found!" \
          "Here's the appropriate part of the HTML page:\n #{msg} \n")
  end

  def disable_unsafe_html_filter(value = true)
    @unsafe_html_filter_disabled = value
  end
end
