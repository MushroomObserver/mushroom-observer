# frozen_string_literal: true

module Views::Controllers::Contributors
  class Index
    # Collapsible "How is contribution calculated?" panel on the
    # contributors index. Two `Components::Table`s inside a
    # `Components::Panel`:
    #
    # 1. Per-field weight table — every `UserStats` field that has
    #    a non-zero weight, with its field-name translation and
    #    numeric weight.
    # 2. Worked-example math table — fixed sample (`EXAMPLE_WEIGHTS`)
    #    showing how a few activities sum to a total contribution
    #    score, with a footer row holding the running total.
    #
    # Both tables run with `show_headers: false`.
    class Legend < Views::Base
      EXAMPLE_WEIGHTS = [
        { field: :images, number: 3, text_key: :users_by_contribution_2a },
        { field: :name_description_editors, number: 1,
          text_key: :users_by_contribution_2b },
        { field: :observations, number: 1,
          text_key: :users_by_contribution_2c },
        { field: :namings, number: 1, text_key: :users_by_contribution_2d },
        { field: :votes, number: 1, text_key: :users_by_contribution_2e }
      ].freeze

      def view_template
        Panel(panel_class: "collapse",
              panel_id: "contribution_legend") do |panel|
          panel.with_heading { render_heading }
          panel.with_heading_links { render_toggle_button }
          panel.with_body { render_body }
        end
      end

      private

      def render_heading
        strong { plain(:users_by_contribution_legend.l) }
      end

      def render_toggle_button
        Link(type: :collapse_toggle,
             target_id: "contribution_legend",
             icon: :info_circle,
             button: :link,
             size: :xs)
      end

      def render_body
        # `.tp` runs textile + paragraph-wrap and returns an
        # html-safe `<p>…</p>` string — trusted_html is the right
        # marker. The intermediate `_2` value is plain prose with
        # no markup or cross-refs, so `.l` + plain suffices.
        div(class: "mb-3") { trusted_html(:users_by_contribution_1.tp) }
        render_weights_table
        p(class: "pt-3") { plain(:users_by_contribution_2.l) }
        render_example_math_table
        trusted_html(:users_by_contribution_3.tp)
      end

      def render_weights_table
        Table(
          ::UserStats.fields_with_weight.keys,
          show_headers: false,
          class: "text-center bg-none mx-lg-5"
        ) do |t|
          # `user_stats_*` values are `[:IMAGES]`-style cross-refs to
          # plain-text root keys ("Images", "Votes", …); needs `.t`
          # for the cross-ref expansion, but the resolved text has
          # no HTML markup so `plain` is sufficient.
          t.column("field") { |f| plain(:"user_stats_#{f}".t) }
          t.column("weight") { |f| plain(::UserStats::ALL_FIELDS[f][:weight]) }
          t.column("spacer") { plain("") }
        end
      end

      def render_example_math_table
        Table(
          show_headers: false,
          class: "table-condensed bg-none w-auto mx-auto"
        ) do |t|
          t.body { render_example_math_rows }
        end
      end

      def render_example_math_rows
        total = 0
        EXAMPLE_WEIGHTS.each_with_index do |example, idx|
          weight = ::UserStats::ALL_FIELDS[example[:field]][:weight]
          total += example[:number] * weight
          render_example_math_row(idx, example, weight)
        end
        render_example_math_total_row(total)
      end

      def render_example_math_row(idx, example, weight)
        tr do
          td do
            if idx.zero?
              span(class: "ml-4")
            else
              plain("+")
            end
            plain(" #{example[:number]} * #{weight}")
          end
          # `users_by_contribution_2[a-e]` cross-refs to the same
          # plain-text root keys as `user_stats_*` above; same logic
          # — `.t` for the cross-ref, `plain` for the resolved text.
          td { plain("(#{example[:text_key].t})") }
          td
        end
      end

      def render_example_math_total_row(total)
        tr do
          td { span(class: "ml-4") { plain(total.to_s) } }
          # Plain text "points" — no markup, no cross-ref.
          td { plain(:users_by_contribution_2f.l) }
          td
        end
      end
    end
  end
end
