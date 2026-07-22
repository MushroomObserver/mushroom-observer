# frozen_string_literal: true

module Views::Controllers::Theme
  # Cantharellaceae color-theme detail page.
  class Cantharellaceae < Views::FullPageBase
    SPECIES = [
      SpeciesRow[:tp, :theme_cantharellaceae_californicus,
                 "Cantharellus californicus", 557],
      SpeciesRow[:tp, :theme_cantharellaceae_cinnabarinus,
                 "Cantharellus cinnabarinus", 551],
      SpeciesRow[:t, :theme_cantharellaceae_cornucopioides,
                 "Craterellus cornucopioides", 465, list_line: "ListLine1"],
      SpeciesRow[:t, :theme_cantharellaceae_tubaeformis,
                 "Craterellus tubaeformis", 462, list_line: "ListLine0"]
    ].freeze

    def view_template
      add_page_title(:theme_cantharellaceae.tl)
      add_context_nav(::Tab::Theme::ShowActions.new)

      SPECIES.each { |row| render(SpeciesParagraph.new(row: row)) }
      trusted_html(:theme_switch.tp(theme: :cantharellaceae.l))
    end
  end
end
