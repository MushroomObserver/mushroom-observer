# frozen_string_literal: true

module Views::Controllers::Users
  class Show
    # User-contribution scoreboard panel.
    class UserStats < Views::Base
      prop :show_user, ::User
      prop :name, ::String
      # Pre-computed in the controller via `UserStatsHelper#user_stats_rows`.
      # `:label` may be either a plain string or a SafeBuffer (the
      # languages-breakdown row).
      prop :rows, _Array(::Hash)
      # `{ field_symbol => path_string }`, controller-built so the
      # view doesn't touch Rails route helpers.
      prop :paths, _Hash(::Symbol, ::String), default: -> { {} }

      def view_template
        render(::Components::Panel.new(panel_id: "user_stats")) do |panel|
          panel.with_heading { :show_user_title.t(user: @name) }
          panel.with_body { render_table }
        end
      end

      private

      def render_table
        @total = 0
        table(class: "table table-condensed bg-none mb-0") do
          @rows.each { |row| render_row(row) }
          render_total_rows if @total.positive?
        end
      end

      def render_row(row)
        if row[:count].nil?
          render_no_count_row(row)
        elsif row[:label].present?
          render_count_row(row)
        end
        @total += row[:points].to_i
      end

      def render_no_count_row(row)
        tr do
          td(colspan: "2") { render_label(row[:label]) }
          td { plain(row[:weight] ? "=" : "") }
          td(align: "right") { plain(row[:points].to_s) }
        end
      end

      def render_count_row(row)
        tr do
          td { render_link_or_label(row) }
          td { plain(count_text(row)) }
          td { plain(row[:weight] ? "=" : "") }
          td(align: "right") { plain(row[:points].to_s) }
        end
      end

      def render_link_or_label(row)
        url = @paths[row[:field]]
        if url
          link_to(url) { render_label(row[:label]) }
        else
          render_label(row[:label])
        end
      end

      def render_label(label)
        if label.is_a?(::ActiveSupport::SafeBuffer)
          trusted_html(label)
        else
          plain(label.to_s)
        end
      end

      def count_text(row)
        row[:weight] ? "#{row[:count]} * #{row[:weight]}" : row[:count].to_s
      end

      def render_total_rows
        tr { td(colspan: "4") { hr } }
        tr do
          td { :show_user_total.l }
          td
          td { "=" }
          td(align: "right") { plain(@total.to_s) }
        end
      end
    end
  end
end
