# frozen_string_literal: true

module Views::Layouts::App
  # Wraps the GTM footer in HTML comments. (The ERB version
  # existed to keep the `<!--JAVASCRIPT-->` / `<!--/JAVASCRIPT-->`
  # comment pair grouped with the script.)
  class JavascriptFooter < Views::Base
    def view_template
      comment { "JAVASCRIPT" }
      render(GtmFooter.new)
      comment { "/JAVASCRIPT" }
    end
  end
end
