# frozen_string_literal: true

module Views::Controllers::Images
  class Show
    # License-history panel — one row per `Image::CopyrightChange`
    # showing the date range, license, and copyright holder, plus a
    # final row for the current license. Hidden when the image has
    # no copyright changes.
    class LicenseHistoryPanel < Views::Base
      prop :image, ::Image

      def view_template
        chgs = @image.copyright_changes.sort_by(&:id)
        return if chgs.empty?

        @chgs = chgs
        Panel do |panel|
          panel.with_body { render_table }
        end
      end

      private

      def render_table
        Table(history_rows,
              variant: :striped, identifier: "license-history",
              class: "table-responsive small") do |t|
          t.column(:dates.ti) { |row| row[:dates] }
          t.column(:license.ti) { |row| trusted_html(row[:license_link]) }
          t.column(:copyright_holder.ti) { |row| trusted_html(row[:holder]) }
        end
      end

      # Builds a row hash per copyright change + one final "current"
      # row. Pre-computed so the Table block stays simple.
      def history_rows
        rows = @chgs.each_with_index.map { |chg, i| change_row(chg, i) }
        rows << current_row
        rows
      end

      def change_row(chg, idx)
        from = idx.zero? ? @image.created_at : @chgs[idx - 1].updated_at
        {
          dates: "#{from.web_date} → #{chg.updated_at.web_date}",
          license_link: license_link_html(chg.license),
          holder: chg.license.copyright_text(chg.year, chg.name)
        }
      end

      def current_row
        from = @chgs.last.updated_at.web_date
        {
          dates: "#{from} → #{Time.zone.now.web_date}",
          license_link: license_link_html(@image.license),
          holder: capture do
            render(::Components::Image::Copyright.new(
                     user: current_user, image: @image
                   ))
          end
        }
      end

      def license_link_html(license)
        capture do
          link_to(license.display_name.t, license.url)
        end
      end
    end
  end
end
