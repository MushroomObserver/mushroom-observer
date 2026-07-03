# frozen_string_literal: true

# Action view for `visual_groups#edit`. The form is
# `Views::Controllers::VisualGroups::Form`; the image-matrix grid is
# `Views::Controllers::VisualGroups::ImageMatrix` (shared with the
# show page).
module Views::Controllers::VisualGroups
  class Edit < Views::FullPageBase
    prop :visual_group, VisualGroup
    prop :user, _Nilable(User)
    prop :filter, _Nilable(String)
    prop :status, String
    prop :pagination_data, _Nilable(PaginationData)
    # Each row is `[Image, included]` where `included` is the
    # boolean from `visual_group_images.included` — `true`, `false`,
    # or `nil` for the `:any` raw-SQL branch.
    prop :subset, _Array(_Tuple(::Image, _Nilable(_Boolean))),
         default: -> { [] }

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
        render(Form.new(@visual_group,
                        visual_model: @visual_group.visual_model))
        render_filter_section
        render_status_count
      end
      render(ImageMatrix.new(
               user: @user, visual_group: @visual_group,
               subset: @subset, status: @status,
               pagination_data: @pagination_data
             ))
      render_bottom_nav
    end

    private

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
        Button(
          name: label, variant: :outline,
          tag: :span, aria_disabled: "true",
          class: "active disabled"
        )
      else
        Button(
          type: :submit,
          name: label,
          html_name: "status",
          value: value,
          variant: :outline
        )
      end
    end

    # Force-reload button for the needs_review view, which pulls
    # fresh inference data on each load. We need a true cache-bypass
    # reload: a same-URL self-link would let Turbo Drive serve its
    # snapshot (stale data), and HTTP-layer caching is less reliable
    # than the explicit `reload(true)` for force-refetch. Phlex's
    # native `a` strips `javascript:` hrefs as a safety measure, but
    # the registered Rails `link_to` helper keeps them.
    def render_reload_link
      Button(
        name: :RELOAD.t,
        class: "ml-2",
        onclick: "window.location.reload(true)"
      )
    end

    def render_filter_text_row
      div(class: "d-flex gap-2 align-items-end") do
        div(class: "form-group mb-0") do
          label(for: "filter") { plain("Filter text:") }
          input(type: "text", name: "filter", id: "filter",
                value: @filter, size: 40, class: "form-control")
        end
        Button(
          type: :submit,
          name: :edit_visual_group_update_filter.t,
          html_name: "commit"
        )
      end
    end

    def render_status_count
      count = @visual_group.image_count(@status)
      p { plain(:"visual_group_count_#{@status}".t(count: count)) }
    end
  end
end
