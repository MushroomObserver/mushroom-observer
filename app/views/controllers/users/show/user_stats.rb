# frozen_string_literal: true

module Views::Controllers::Users
  class Show
    # User-contribution scoreboard panel.
    class UserStats < Views::Base
      prop :show_user, ::User
      prop :name, ::String
      # Pre-computed in the controller (via
      # `UsersController::UserStatsBuilder#user_stats_rows`) so the
      # `Language.pluck(...)` query for the languages-summary row
      # doesn't run from the view. `:label` may be either a plain
      # string or a SafeBuffer.
      prop :rows, _Array(::Hash)

      # `{field => [route_helper, query_param]}`. Most rows feed
      # `<plural>_path(by_user: uid)`; the exceptions
      # (`*_versions` → `by_editor`, `*_description_{authors,editors}`,
      # `comments_for`, `life_list`) tweak the helper or the param.
      # Phlex views see every Rails route helper via
      # `Components::Base`'s `Phlex::Rails::Helpers::Routes` include,
      # so this lookup lives in the view rather than being
      # controller-built.
      FIELD_PATHS = {
        comments: [:comments_path, :by_user],
        comments_for: [:comments_path, :for_user],
        images: [:images_path, :by_user],
        locations: [:locations_path, :by_user],
        location_versions: [:locations_path, :by_editor],
        location_description_authors:
          [:location_descriptions_index_path, :by_author],
        location_description_editors:
          [:location_descriptions_index_path, :by_editor],
        names: [:names_path, :by_user],
        name_versions: [:names_path, :by_editor],
        name_description_authors:
          [:name_descriptions_index_path, :by_author],
        name_description_editors:
          [:name_descriptions_index_path, :by_editor],
        observations: [:observations_path, :by_user],
        species_lists: [:species_lists_path, :by_user],
        life_list: [:checklist_path, :id]
      }.freeze

      def view_template
        Panel(panel_id: "user_stats") do |panel|
          panel.with_heading { :show_user_title.t(user: @name) }
          panel.with_body { render_table }
        end
      end

      private

      def render_table
        @total = 0
        Table(variant: :condensed,
              class: "bg-none mb-0",
              show_headers: false) do |t|
          t.body do
            @rows.each { |row| render_row(row) }
            render_total_rows if @total.positive?
          end
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
        url = field_path(row[:field])
        if url
          link_to(url) { render_label(row[:label]) }
        else
          render_label(row[:label])
        end
      end

      def field_path(field)
        helper, key = FIELD_PATHS[field]
        return nil unless helper

        send(helper, key => @show_user.id)
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
