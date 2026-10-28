# frozen_string_literal: true

module Views::Controllers::Interests
  # Interests / subscriptions page — type filter pills + paginated
  # table of objects the current user is subscribed to.
  class Index < Views::FullPageBase
    prop :interests, _Array(::Interest)
    prop :types, _Array(::String)
    prop :selected_type, _Nilable(::String), default: nil
    prop :pagination_data, ::PaginationData

    def view_template
      add_page_title(:list_interests_title.l)
      add_type_filters(**type_filter_args) if show_type_filter?
      add_pagination(@pagination_data)
      container_class(:wide)

      render_intro
      PaginatedResults do
        render_interests_table if @interests.any?(&:target)
      end
    end

    private

    def render_intro
      ContentPadded { p(class: "mb-3") { plain(:list_interests_intro.l) } }
    end

    def show_type_filter?
      @selected_type || (@types.length > 1 && @pagination_data.num_total > 1)
    end

    def type_filter_args
      {
        types: [@selected_type.presence || "all"], multiple: false,
        filterable_types: @types.map(&:to_sym),
        type_label: ->(type) { type.to_s.underscore.pluralize.to_sym.ti },
        path_for: lambda do |type|
          url = type ? interests_path(type: type) : interests_path
          add_q_param(url)
        end
      }
    end

    def render_interests_table
      rows = @interests.select(&:target)
      Table(rows, class: "table-striped table-align-middle",
                  identifier: "interests", show_headers: false) do |t|
        t.column("summary") { |item| summary_cell(item) }
        t.column("actions") { |item| actions_cell(item) }
      end
    end

    def summary_cell(item)
      capture do
        strong { render_summary_link(item) }
        render_pending_notice(item)
      end
    end

    def render_summary_link(item)
      Link(type: :get, name: item_summary(item).t.strip_html,
           target: summary_target(item)) do
        trusted_html(item_summary(item).t)
      end
    end

    def summary_target(item)
      target = item.target
      if item.target_type == "NameTracker"
        new_tracker_of_name_path(target.name_id)
      else
        target.show_link_args
      end
    end

    # Was Interest#summary -- moved here (#4901) since its only
    # caller was this render. NameTracker#summary (the target.summary
    # branch) stays on the model unchanged: it has a second, non-render
    # caller (InterestsController#find_relevant_interests sorts by
    # target.text_name, an alias of summary, for NameTracker targets).
    def item_summary(item)
      return item.target.summary if item.target_type == "NameTracker"

      state = item.state ? :watching.ti : :ignoring.ti
      type_label = append_colon(item.target_type.underscore.to_sym.l)
      target = item.target ? item.target_format_name : "--"
      "#{state} #{type_label}#{target}"
    end

    def actions_cell(item)
      capture do
        ButtonGroup do
          render_toggle_button(item)
          render_destroy_button(item)
        end
      end
    end

    def render_toggle_button(item)
      icon = item.state ? :ignore : :watch
      tooltip = if item.state
                  :list_interests_mute_tooltip.l
                else
                  :list_interests_resume_tooltip.l
                end
      Button(type: :patch, name: tooltip, icon: icon, variant: :outline,
             show_label: :responsive,
             target: interest_path(item.target_id),
             params: { type: item.target_type,
                       state: item.state ? -1 : 1 })
    end

    def render_destroy_button(item)
      Button(type: :delete, name: :delete.ti, icon: :delete,
             variant: :outline, show_label: :responsive,
             target: interest_path(item.target_id),
             params: { type: item.target_type })
    end

    def render_pending_notice(item)
      return unless item.target_type == "NameTracker"

      target = item.target
      return unless target.note_template.present? && !target.approved

      br
      plain(:list_name_tracker_pending_approval.l)
    end
  end
end
