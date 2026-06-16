# frozen_string_literal: true

module Views::Controllers::Theme
  # Amanita color-theme detail page.
  class Amanita < Views::Base
    SPECIES = [
      SpeciesRow[:tp, :theme_amanita_pachycolea, "Amanita pachycolea", 644],
      SpeciesRow[:tp, :theme_amanita_muscaria, "Amanita muscaria", 651],
      SpeciesRow[:tp, :theme_amanita_velosa, "Amanita velosa", 623],
      SpeciesRow[:t, :theme_amanita_calyptroderma,
                 "The fall form of **__Amanita calyptroderma__**", 669,
                 list_line: "ListLine0", raw_link_label: true],
      SpeciesRow[:t, :theme_amanita_phalloides, "Amanita phalloides", 636,
                 list_line: "ListLine1"]
    ].freeze

    def view_template
      add_page_title(:theme_amanita.tl)
      add_context_nav(::Tab::Theme::ShowActions.new)

      SPECIES.each { |row| render(SpeciesParagraph.new(row: row)) }
      trusted_html(:theme_switch.tp(theme: :Amanita.l))
    end
  end
end
