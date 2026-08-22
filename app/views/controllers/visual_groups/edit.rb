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

    def view_template
      add_edit_title(@visual_group)
      container_class(:full)

      Container(width: :text) do
        render_top_nav
        render(Form.new(@visual_group,
                        visual_model: @visual_group.visual_model,
                        turbo: true))
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
      Link(type: :get, name: :visual_group_show.t,
           target: visual_group_path(@visual_group))
      whitespace
      plain("|")
      whitespace
      Link(type: :get, name: :visual_group_index.t,
           target: visual_model_visual_groups_path(
             @visual_group.visual_model
           ))
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
          Link(type: :get, name: name[0],
               target: distinct_name_filter_path(name[0]))
          br
        end
      end
    end

    def distinct_name_filter_path(name)
      edit_visual_group_path(@visual_group,
                             visual_group_filter: { filter: name },
                             anchor: "filter_options")
    end

    def render_filter_form
      render(FilterForm.new(
               visual_group: @visual_group, status: @status, filter: @filter
             ))
    end

    def render_status_count
      count = @visual_group.image_count(@status)
      p { plain(:"visual_group_count_#{@status}".t(count: count)) }
    end
  end
end
