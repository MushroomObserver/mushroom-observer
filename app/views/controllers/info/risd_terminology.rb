# frozen_string_literal: true

module Views::Controllers::Info
  # Fungal Terminology cheat sheet — purely static nested lists.
  class RisdTerminology < Views::Base
    GROUPS = [
      ["Overall shape:",
       ["Crust or Parchment Fungi", "Cup Fungi", "Gasteroid", "Stinkhorn"]],
      ["Pileus shape from side:",
       ["Campanulate", "Convoluted", "Cylindrical ", "Depressed",
        "Plane to Uplifted", "Umbonate"]],
      ["Pileus surface:",
       ["Glabrous", "Glutinous", "Rugose (Wrinkled)", "Sulcate",
        "Translucent Striate", "Zonate"]],
      ["Hymenophore shape:",
       %w[Gilled Pored Smooth Toothed]],
      ["Stipe shape",
       ["Base Enlarged", "Base Pinched", "Clavate", "Clavate-bulbous",
        "Equal", "Incrassate", "Tapered Downward",
        "Tapered Upward [Subclavate]", "Ventricose"]],
      ["Stipe attachment",
       %w[Central Lateral Off-center Sessile]],
      ["Universal veil:",
       ["Collar [Circumsessile]", "Constricted [Flaring]",
        "Fragmented [Scaly]", "Gelatinous", "Indistinct",
        "Powdery [Farinose]", "Saccate", "Zoned [Rings]"]],
      ["Partial veil:",
       ["Double", "Intermediate", "Peronate [Sheathlike]", "Single",
        "Stellate"]],
      ["Gill attachment:",
       ["Adnate", "Adnexed", "Notched (Sinuate)", "Subdecurrent"]]
    ].freeze

    def view_template
      add_page_title("Fungal Terminology")
      GROUPS.each { |label, items| render_group(label, items) }
    end

    private

    def render_group(label, items)
      ul do
        li do
          plain(label)
          ul { items.each { |item| li { plain(item) } } }
        end
      end
    end
  end
end
