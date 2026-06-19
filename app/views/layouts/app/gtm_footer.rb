# frozen_string_literal: true

module Views::Layouts::App
  # Legacy Google Analytics (`analytics.js`, the `ga(...)` API)
  # bootstrap `<script>` rendered just before `</body>` in
  # production only.
  class GtmFooter < Views::Base
    SCRIPT = <<~JS
      (function (i, s, o, g, r, a, m) {
        i['GoogleAnalyticsObject'] = r;
        i[r] = i[r] || function () {
            (i[r].q = i[r].q || []).push(arguments)
        }, i[r].l = 1 * new Date();
        a = s.createElement(o), m = s.getElementsByTagName(o)[0];
        a.async = 1;
        a.src = g;
        m.parentNode.insertBefore(a, m)
      })
      (window, document, 'script', '//www.google-analytics.com/analytics.js', 'ga');
      ga('create', 'UA-1916187-1', 'auto');
      ga('send', 'pageview');
    JS

    def view_template
      return unless Rails.env.production?

      script { trusted_html(::ActiveSupport::SafeBuffer.new(SCRIPT)) }
    end
  end
end
