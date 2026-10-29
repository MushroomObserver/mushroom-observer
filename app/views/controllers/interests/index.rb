# frozen_string_literal: true

module Views::Controllers::Interests
  # Interests / subscriptions page — type filter + paginated table
  # of objects the current user is subscribed to.
  class Index < Views::FullPageBase
    prop :interests, _Array(::Interest)
    prop :types, _Array(::String)
    prop :selected_type, _Nilable(::String), default: nil
    prop :states, _Array(::String)
    prop :selected_state, _Nilable(::String), default: nil
    prop :pagination_data, ::PaginationData

    def view_template
      add_page_title(:list_interests_title.l)
      register_filters
      add_pagination(@pagination_data)
      container_class(:wide)

      render_intro
      PaginatedResults do
        if @interests.any?(&:target)
          render_interests_table
        else
          ContentPadded { p { plain(:list_interests_none.l) } }
        end
      end
    end

    private

    def register_filters
      add_type_filters(**type_filter_args) if show_type_filter?
      add_type_filters(**state_filter_args) if show_state_filter?
    end

    def render_intro
      ContentPadded { p(class: "mb-3") { plain(:list_interests_intro.l) } }
    end

    def show_type_filter?
      @selected_type || (@types.length > 1 && @pagination_data.num_total > 1)
    end

    def show_state_filter?
      @selected_state || (@states.length > 1 && @pagination_data.num_total > 1)
    end

    def type_filter_args
      {
        types: [@selected_type.presence || "all"], multiple: false,
        filterable_types: @types.map(&:to_sym), show_intro: true, key: :type,
        type_label: ->(type) { type.to_s.underscore.pluralize.to_sym.ti },
        path_for: lambda do |type|
          params = { type: type, state: @selected_state.presence }.compact
          add_q_param(interests_path(**params))
        end
      }
    end

    def state_filter_args
      {
        types: [@selected_state.presence || "all"], multiple: false,
        filterable_types: @states.map(&:to_sym),
        show_intro: !show_type_filter?, key: :state,
        type_label: ->(state) { state.to_s.underscore.to_sym.ti },
        path_for: lambda do |state|
          params = { type: @selected_type.presence, state: state }.compact
          add_q_param(interests_path(**params))
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
        strong do
          plain(append_colon(summary_prefix(item)))
          render_object_link(item)
        end
        render_pending_notice(item)
      end
    end

    # Inert lead-in text ("Watching Observation") -- not part of the
    # link, only the title after it is. No colon here -- append_colon
    # adds it at the render site above.
    def summary_prefix(item)
      return item.target.summary_prefix if item.target_type == "NameTracker"

      state = item.state ? :watching.ti : :ignoring.ti
      "#{state} #{item.target_type.underscore.to_sym.l}"
    end

    # NameTracker has no show page -- link to the name tracker editor
    # instead of Components::Link::Object's default show_link_args.
    def render_object_link(item)
      return render_name_tracker_link(item) if item.target_type == "NameTracker"

      Link(type: :object, object: item.target,
           name: item.target_format_name.t)
    end

    def render_name_tracker_link(item)
      Link(type: :get, name: item.target.summary_title.t,
           target: new_tracker_of_name_path(item.target.name_id)) do
        trusted_html(item.target.summary_title.t)
      end
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
      icon = item.state ? :hide : :show
      label = item.state ? :ignore.ti : :watch.ti
      tooltip = if item.state
                  :list_interests_mute_tooltip.l
                else
                  :list_interests_resume_tooltip.l
                end
      Button(type: :patch, name: label, icon: icon, variant: :outline,
             show_label: :responsive, data: { title: tooltip },
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
