# frozen_string_literal: true

module Views::Controllers::Locations
  module Help
    # Help page for location-naming conventions. Static content —
    # intro paragraph, examples table, numbered rules list. All copy
    # lives in `en.txt`.
    class Show < Views::FullPageBase
      EXAMPLES = [
        ["Albion,California,  USA",
         "Albion, California, USA",
         "Use correct spacing and commas"],
        ["Albion, California",
         "Albion, California, USA",
         "Include country"],
        ["Unknown",
         "Earth",
         "“Earth” is fallback"],
        ["USA, North America",
         "North America",
         "Continents are okay"],
        ["San Francisco, USA",
         "San Francisco, California, USA",
         "Include state or province"],
        ["San Francisco, CA, USA",
         "San Francisco, California, USA",
         "Do not abbreviate state"],
        ["San Francisco, San Francisco Co., California, USA",
         "San Francisco, California, USA",
         "Leave off county for towns and cities"],
        ["Tilden Park, California, USA",
         "Tilden Park, Contra Costa Co., California, USA",
         %(Include county for other units<sup>(*)</sup>)],
        ["Tilden Park, Kensington, California, USA",
         "Tilden Park, Contra Costa Co., California, USA",
         %(Place parks in county, not nearby town <sup>(*)</sup>)],
        ["Albis Mountain Range, Zurich area, Switzerland",
         "Albis Mountain Range, Near Zurich, Switzerland",
         "Use “near” instead of “area”"],
        ["Southern California, California, USA",
         "Southern California, USA",
         %(Don’t repeat state with “Southern”, “Northern” etc. <sup>(*)</sup>)],
        ["South California, USA",
         "Southern California, USA",
         "Use “Southern”, not “South”"],
        ["Western Australia",
         "Western Australia, Australia",
         "Here “Western” is part of the state’s name"],
        ["Mt Tam SP, Marin County, CA, USA.",
         "Mount Tamalpais State Park, Marin Co., California, USA",
         "Avoid abbreviations"],
        ["Washington, DC, USA",
         "Washington DC, USA",
         "This is a common mistake"],
        ["bedford, new york, usa",
         "Bedford, New York, USA",
         "Use correct capitalization"],
        ["Hong Kong, China N22.498, E114.178",
         "Hong Kong, China",
         "Don’t include latitude/longitude"],
        ["Washington DC, USA in wood chips",
         "Washington DC, USA",
         "Don’t include substrate"],
        ["Washington DC, USA (near the mall)",
         "The Mall, Washington DC, USA",
         "Another common mistake"],
        ["Montréal, Québec, Canada",
         "Montreal, Quebec, Canada",
         "Avoid accents"],
        ["10th Ave. & Lincoln Way, San Francisco, CA USA",
         "10th Ave. and Lincoln Way, San Francisco, California, USA",
         "Spell out “and” for intersections"]
      ].freeze

      RULES = [
        [:reversible,   :location_help_rule_reversible],
        [:countries,    :location_help_rule_countries],
        [:states,       :location_help_rule_states],
        [:counties,     :location_help_rule_counties],
        [:near,         :location_help_rule_near],
        [:southern,     :location_help_rule_southern],
        [:abbr,         :location_help_rule_abbr],
        [:other,        :location_help_rule_other],
        [:good_habits,  :location_help_rule_good_habits]
      ].freeze

      def view_template
        add_page_title(page_title)

        trusted_html(:location_help_intro.tp)
        h2 { :location_help_example_title.l }
        render_examples_table
        render_footnote
        h2 { trusted_html(:location_help_rules_title.t) }
        render_rules_list
      end

      private

      def page_title
        capture { span(class: "text-nowrap") { :location_help_title.l } }
      end

      def render_footnote
        p(class: "mt-3") do
          sup { "(*)" }
          plain(" ")
          plain(:location_help_example_help.l)
        end
      end

      def render_examples_table
        table(class: "table table-striped table-location-help") do
          thead { render_examples_header }
          tbody { EXAMPLES.each { |row| render_examples_row(row) } }
        end
      end

      def render_examples_header
        tr do
          th { :location_help_bad.l }
          th { :location_help_good.l }
          th { :location_help_explanation.l }
        end
      end

      def render_examples_row(row)
        bad, good, explanation = row
        tr do
          td { plain(bad) }
          td { plain(good) }
          td { render_explanation(explanation) }
        end
      end

      # Explanation strings may include a literal `<sup>(*)</sup>`
      # footnote marker. Split on it and emit `sup` as a Phlex tag.
      def render_explanation(text)
        if text =~ %r{\A(.*?)<sup>\(\*\)</sup>(.*)\z}
          plain(Regexp.last_match(1))
          sup { "(*)" }
          plain(Regexp.last_match(2))
        else
          plain(text)
        end
      end

      def render_rules_list
        ol do
          RULES.each do |anchor, key|
            li(id: anchor.to_s) { trusted_html(key.tp) }
          end
        end
      end
    end
  end
end
