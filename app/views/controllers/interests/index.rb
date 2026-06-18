# frozen_string_literal: true

module Views::Controllers::Interests
  # Interests / subscriptions page — type filter pills + paginated
  # table of objects the current user is subscribed to.
  class Index < Views::FullPageBase
    prop :interests, _Array(::Interest)
    prop :types, _Array(::String)
    prop :selected_type, _Nilable(::String), default: nil
    prop :pagination_data, ::PaginationData
    prop :error, _Nilable(::String), default: nil

    def view_template
      add_page_title(:list_interests_title.l)
      add_pagination(@pagination_data)
      container_class(:wide)
      flash_error(@error) if @error && @interests.none?(&:target)

      render_type_filter if show_type_filter?
      paginated_results { render_interests_table if @interests.any?(&:target) }
    end

    private

    def show_type_filter?
      @selected_type || (@types.length > 1 && @pagination_data.num_total > 1)
    end

    def render_type_filter
      div(class: "btn-group pb-1 hidden-xs text-nowrap mt-5") do
        span(class: "btn btn-default btn-sm disabled") { :rss_show.l }
        render_filter_pill(nil, :rss_all.l, interests_path)
        @types.each do |type|
          label = type.underscore.pluralize.upcase.to_sym.l
          render_filter_pill(type, label, interests_path(type: type))
        end
      end
    end

    def render_filter_pill(type, label, url)
      active = (type.to_s == @selected_type.to_s)
      span(class: class_names("btn btn-default btn-sm", "active" => active)) do
        if active
          plain(label)
        else
          link_to(add_q_param(url)) { plain(label) }
        end
      end
    end

    def render_interests_table
      rows = @interests.select(&:target)
      render(::Components::Table.new(rows, class: "table-striped",
                                           show_headers: false)) do |t|
        t.column("summary") do |item|
          capture { strong { trusted_html(item.summary.t) } }
        end
        t.column("actions") { |item| actions_cell(item) }
      end
    end

    def actions_cell(item)
      capture do
        render_show_link(item)
        plain(" | ")
        render_toggle_link(item)
        plain(" | ")
        render_destroy_link(item)
        render_pending_notice(item)
      end
    end

    def render_destroy_link(item)
      link_to(:DESTROY.l,
              set_interest_path(type: item.target_type,
                                id: item.target_id, state: 0))
    end

    def render_show_link(item)
      target = item.target
      label = :show_object.l(type: target.type_tag)
      if item.target_type == "NameTracker"
        link_to(label, new_tracker_of_name_path(target.name_id))
      else
        link_to(label, target.show_link_args)
      end
    end

    def render_toggle_link(item)
      label = if item.state
                :list_interests_turn_off.l
              else
                :list_interests_turn_on.l
              end
      link_to(label,
              set_interest_path(type: item.target_type,
                                id: item.target_id,
                                state: item.state ? -1 : 1))
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
