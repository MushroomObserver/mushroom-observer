# frozen_string_literal: true

module Views::Layouts::App
  # Google Tag Manager `<noscript>` iframe — rendered immediately
  # after the opening `<body>` in `application.html.erb`, where
  # the surrounding `if Rails.env == "production"` check gates it.
  # The markup itself is static.
  class GtmIframe < Views::Base
    def view_template
      noscript do
        iframe(
          src: "https://www.googletagmanager.com/ns.html?id=GTM-PJKJR59" \
               "&nojscript=true",
          height: "0", width: "0",
          style: "display:none;visibility:hidden"
        )
      end
    end
  end
end
