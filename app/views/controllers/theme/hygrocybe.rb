# frozen_string_literal: true

module Views::Controllers::Theme
  # Hygrocybe color-theme detail page.
  class Hygrocybe < Views::Base
    SPECIES = [
      SpeciesRow[:tp, :theme_hygrocybe_miniata, "Hygrocybe miniata", 369],
      SpeciesRow[:tp, :theme_hygrocybe_pittacina, "Hygrocybe pittacina", 368],
      SpeciesRow[:t, :theme_hygrocybe_conica, "Hygrocybe conica", 371,
                 list_line: "ListLine1"],
      SpeciesRow[:t, :theme_hygrocybe_punicea, "Hygrocybe punicea", 366,
                 list_line: "ListLine0"]
    ].freeze

    def view_template
      add_page_title(:theme_hygrocybe.tl)
      add_context_nav(::Tab::Theme::ShowActions.new)

      SPECIES.each { |row| render(SpeciesParagraph.new(row: row)) }
      trusted_html(:theme_switch.tp(theme: :Hygrocybe.l))
    end
  end
end
