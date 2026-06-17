# frozen_string_literal: true

module Views::Layouts::App
  # Google Tag Manager `<noscript>` iframe — rendered immediately
  # after the opening `<body>` in `application.html.erb`. Static
  # markup; the production-only gate is on `Views::Layouts::App::GtmFooter`.
  class GtmIframe < Views::Base
    def view_template
      comment { " Google Tag Manager (noscript) " }
      noscript do
        iframe(
          src: "https://www.googletagmanager.com/ns.html?id=GTM-PJKJR59" \
               "&nojscript=true",
          height: "0", width: "0",
          style: "display:none;visibility:hidden"
        )
      end
      comment { " End Google Tag Manager (noscript) " }
    end
  end
end
