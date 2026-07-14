# frozen_string_literal: true

module Views::Controllers::Locations
  module Countries
    # Countries-and-other-localities index — three side-by-side columns:
    # known countries (with obs counts), missing countries (the canonical
    # country list minus the ones with obs), and unmatched country
    # strings observed in the wild.
    class Index < Views::FullPageBase
      # `CountryCounter` carries three lists: `known_by_count`,
      # `missing`, `unknown_by_count` (each an Array of [name, count]
      # pairs).
      prop :cc, ::CountryCounter

      def view_template
        register_chrome

        Row do
          render_column(:known)
          render_column(:missing)
          render_column(:unknown)
        end
      end

      private

      def register_chrome
        add_page_title(:list_countries_title.l)
        add_context_nav(::Tab::Location::CountriesActions.new)
        container_class(:wide)
      end

      def render_column(key)
        div(class: Grid::THIRD) do
          h4 do
            plain(column_label(key))
            plain(" (#{column_data(key).length})")
          end
          column_data(key).each do |country, count|
            render_row(key, country, count)
          end
        end
      end

      def column_label(key)
        case key
        when :known   then :list_countries_known.l
        when :missing then :list_countries_missing.l
        when :unknown then :list_countries_unknown.l
        end
      end

      def column_data(key)
        case key
        when :known   then @cc.known_by_count
        when :missing then @cc.missing
        when :unknown then @cc.unknown_by_count
        end
      end

      def render_row(key, country, count)
        if key == :missing
          plain(country)
        else
          str = count ? "#{country}: #{count}" : country
          link_to(str, locations_path(country: country))
        end
        br
      end
    end
  end
end
