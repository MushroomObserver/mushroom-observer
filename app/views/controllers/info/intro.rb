# frozen_string_literal: true

module Views::Controllers::Info
  # Intro / project-overview page. Pure static textile-rendered copy.
  class Intro < Views::FullPageBase
    def view_template
      add_page_title(:intro_title.l)

      trusted_html(:intro_purpose.tp)
      trusted_html(:intro_image_sharing.tp)
      trusted_html(:intro_source_code.tp(
                     repo: MO.code_repository,
                     readme: "#{MO.code_repository}/developer-startup"
                   ))
      trusted_html(:intro_governance.tp)
      trusted_html(:intro_note.tp)
    end
  end
end
