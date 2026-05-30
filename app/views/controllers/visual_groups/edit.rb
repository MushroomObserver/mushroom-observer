# frozen_string_literal: true

# Action view for `visual_groups#edit`. Replaces the 94-line
# `edit.html.erb`. The form itself is already Phlex
# (`Views::Controllers::VisualGroups::Form`). The image matrix grid
# is still ERB (`_image_matrix.html.erb`) — kept via the
# `view_context.render(partial: …)` bridge to keep the scope tight;
# can move to Phlex in a follow-up.
module Views::Controllers::VisualGroups
  class Edit < Views::Base
    prop :visual_group, VisualGroup
    prop :filter, _Nilable(String)
    prop :status, String
    prop :pagination_data, _Nilable(PaginationData)
    prop :subset, _Nilable(_Array(_Any))

    STATUSES = [
      ["needs_review", :visual_group_needs_review],
      ["included", :visual_group_included],
      ["excluded", :visual_group_excluded]
    ].freeze

    def view_template
      add_edit_title(@visual_group)
      container_class(:full)

      div(class: "container-text") do
        render_top_nav
        render(Views::Controllers::VisualGroups::Form.new(
                 @visual_group, visual_model: @visual_group.visual_model
               ))
        render_filter_section
        render_status_count
      end
      render_image_matrix
      render_bottom_nav
    end

    private

    # NOTE: The pre-conversion ERB rendered `<p id="notice"><%= notice %></p>`
    # — a rails-scaffold-generated remnant. Dropped: the global flash
    # banner in the application layout already surfaces flash[:notice]
    # for every controller, so this paragraph was a near-empty no-op
    # on every page load. No tests pinned `#notice`.

    def render_top_nav
      p { render_back_nav_links }
    end

    def render_bottom_nav
      p { render_back_nav_links }
    end

    def render_back_nav_links
      link_to(:visual_group_show.t, visual_group_path(@visual_group))
      whitespace
      plain("|")
      whitespace
      link_to(:visual_group_index.t,
              visual_model_visual_groups_path(@visual_group.visual_model))
    end

    def render_filter_section
      span(id: "filter_options") { hr }
      render_distinct_names
      hr
      render_filter_form
    end

    def render_distinct_names
      p do
        strong { plain("#{:visual_group_includes_names.t}:") }
        br
        @visual_group.distinct_names.each do |name|
          link_to(name[0], distinct_name_filter_path(name[0]))
          br
        end
      end
    end

    def distinct_name_filter_path(name)
      edit_visual_group_path(@visual_group, filter: name,
                                            anchor: "filter_options")
    end

    # Combined filter form: status (button-group) + filter text input.
    # Both are inside one form so clicking a status submit button
    # carries the current text along, and submitting the text input
    # preserves the current status via the hidden status field.
    def render_filter_form
      form(action: edit_visual_group_path(@visual_group), method: "get",
           id: "visual_group_filters_form", class: "form-inline mb-4") do
        # Hidden status field: preserves the current status when the
        # user submits via the text-input's submit. The status submit
        # buttons below carry their own `name="status" value="<s>"`;
        # because the hidden field appears FIRST in the DOM, the
        # button's value (later in DOM) wins in Rails' last-value-wins
        # param parsing.
        input(type: "hidden", name: "status", value: @status,
              autocomplete: "off")
        render_status_button_row
        render_filter_text_row
      end
    end

    def render_status_button_row
      div(class: "d-flex gap-2 align-items-center mb-3") do
        strong(class: "mb-0") do
          plain("#{:edit_visual_group_filter_options.t}:")
        end
        div(class: "btn-group", role: "group") do
          STATUSES.each do |(value, label_key)|
            render_status_button(value, label_key.t)
          end
        end
        render_reload_link if @status == "needs_review"
      end
    end

    def render_status_button(value, label)
      if @status == value
        span(class: "btn btn-outline-default active disabled",
             aria_disabled: "true") { plain(label) }
      else
        button(type: "submit", name: "status", value: value,
               class: "btn btn-outline-default") do
          plain(label)
        end
      end
    end

    # Force-reload button for the needs_review view, which pulls
    # fresh inference data on each load. We need a true cache-bypass
    # reload: a same-URL self-link would let Turbo Drive serve its
    # snapshot (stale data), and HTTP-layer caching is less reliable
    # than the explicit `reload(true)` for force-refetch. Phlex's
    # native `a` strips `javascript:` hrefs as a safety measure, but
    # the registered Rails `link_to` helper keeps them — same
    # mechanism the ERB this replaces relied on.
    def render_reload_link
      link_to(:RELOAD.t, "javascript:window.location.reload(true)",
              class: "btn btn-default ml-2")
    end

    def render_filter_text_row
      div(class: "d-flex gap-2 align-items-end") do
        div(class: "form-group mb-0") do
          label(for: "filter") { plain("Filter text:") }
          input(type: "text", name: "filter", id: "filter",
                value: @filter, size: 40, class: "form-control")
        end
        input(type: "submit", name: "commit",
              value: :edit_visual_group_update_filter.t,
              class: "btn btn-default")
      end
    end

    def render_status_count
      count = @visual_group.image_count(@status)
      p { plain(:"visual_group_count_#{@status}".t(count: count)) }
    end

    # `_image_matrix.html.erb` renders all-Phlex inner components
    # (`MatrixTable` / `MatrixBox` / `Panel` / `InteractiveImage`) plus
    # the `visual_group_status_links` ERB helper. Bridge via
    # `view_context.render(partial: …)` to keep this PR's scope to the
    # action template; the partial-to-Phlex conversion can land later.
    def render_image_matrix
      trusted_html(
        view_context.render(partial: "visual_groups/image_matrix",
                            locals: { visual_group: @visual_group,
                                      status: @status })
      )
    end
  end
end
