# frozen_string_literal: true

module Views::Controllers::Theme
  # Agaricus color-theme detail page.
  class Agaricus < Views::FullPageBase
    SPECIES = [
      SpeciesRow[:tp, :theme_agaricus_campestris, "Agaricus campestris", 694],
      SpeciesRow[:tp, :theme_agaricus_cupreobrunneus,
                 "Agaricus cupreobrunneus", 693],
      SpeciesRow[:tp, :theme_agaricus_subrufescens,
                 "Agaricus subrufescens", 699],
      SpeciesRow[:tp, :theme_agaricus_semotus, "Agaricus semotus", 687],
      SpeciesRow[:tp, :theme_agaricus_augustus, "Agaricus augustus", 708],
      SpeciesRow[:t, :theme_agaricus_xanthodermus,
                 "Agaricus xanthodermus", 679, list_line: "ListLine0"],
      SpeciesRow[:t, :theme_agaricus_lilaceps,
                 "Agaricus lilaceps", 690, list_line: "ListLine1"]
    ].freeze

    def view_template
      add_page_title(:theme_agaricus.tl)
      add_context_nav(::Tab::Theme::ShowActions.new)

      SPECIES.each { |row| render(SpeciesParagraph.new(row: row)) }
      trusted_html(:theme_switch.tp(theme: :agaricus.l))
    end
  end
end
