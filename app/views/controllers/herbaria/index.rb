# frozen_string_literal: true

module Views::Controllers::Herbaria
  # Paginated herbaria index. Page chrome + optional merge-mode
  # Alert + `Components::Table` of one row per herbarium.
  class Index < Views::FullPageBase
    prop :query, ::Query
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::Herbarium)
    prop :merge, _Nilable(::Herbarium), default: nil

    def view_template
      container_class(:full)
      add_index_title(@query)
      add_context_nav(::Tab::Herbarium::Index.new(query: @query))
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)

      render_merge_alert if @merge

      PaginatedResults do
        render_table if @objects.any?
      end
    end

    private

    def nonpersonal?
      @query&.params&.dig(:nonpersonal)
    end

    def render_merge_alert
      Container(width: :text, class: "mt-3") do
        Alert(level: :warning) do
          trusted_html(
            :herbarium_index_merge_help.tp(
              name: @merge.format_name,
              url: reload_with_args(merge: nil)
            )
          )
        end
      end
    end

    def render_table
      Table(@objects,
            variant: :striped, identifier: "herbarium",
            class: "w-100 mt-3") { |t| build_table_columns(t) }
    end

    def build_table_columns(table)
      table.column(:herbarium_code.t) { |h| plain(h.code.to_s) }
      table.column(:herbarium_index_records.t) do |h|
        plain(h.herbarium_records.length)
      end
      table.column(:herbarium.ti) { |h| render_name_cell(h) }
      table.column(user_header) { |h| render_user_cell(h) }
    end

    def user_header
      nonpersonal? ? "" : :user.ti
    end

    # --- 3rd column: name link / merge POST + edit / merge actions --

    def render_name_cell(herbarium)
      render_name_link(herbarium)
      render_admin_actions(herbarium) if admin_actions?(herbarium)
    end

    def render_name_link(herbarium)
      if !@merge || !current_user
        render_plain_name_link(herbarium)
      elsif @merge != herbarium
        render_merge_target_button(herbarium)
      else
        render_self_merge_marker(herbarium)
      end
    end

    def render_plain_name_link(herbarium)
      link_to(herbarium.name.t, herbarium_path(herbarium),
              class: "herbarium_link_#{herbarium.id}")
    end

    # Cannot POST from a link without js; use a button instead.
    def render_merge_target_button(herbarium)
      Button(
        type: :post,
        variant: :strip,
        name: herbarium.name.t,
        target: herbaria_merges_path(src: @merge.id,
                                     dest: herbarium.id),
        class: "herbaria_merges_link_#{@merge.id}_#{herbarium.id}",
        confirm: :are_you_sure.l
      )
    end

    def render_self_merge_marker(herbarium)
      plain("[")
      i(style: "color:red") { plain(herbarium.name.t) }
      plain("]")
    end

    def admin_actions?(herbarium)
      return false if !current_user || @merge

      herbarium.can_edit?(current_user) || in_admin_mode?
    end

    def render_admin_actions(herbarium)
      plain(" [")
      Button(
        type: :edit,
        target: herbarium,
        name: :edit.ti,
        icon: nil, variant: :strip,
        class: "edit_herbarium_link_#{herbarium.id}"
      )
      plain(" | ")
      Button(
        type: :get,
        name: :merge.ti,
        target: herbaria_path(merge: herbarium.id),
        icon: nil, variant: :strip,
        class: "merge_herbarium_link_#{herbarium.id}"
      )
      plain("]")
    end

    # --- 4th column: personal-user cell ----------------------------

    def render_user_cell(herbarium)
      return if nonpersonal? || herbarium.personal_user.blank?

      span(title: herbarium.personal_user.unique_text_name) do
        Link(type: :user, user: herbarium.personal_user)
      end
    end
  end
end
