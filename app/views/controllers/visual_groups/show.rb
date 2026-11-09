# frozen_string_literal: true

# Action view for `visual_groups#show`. The image matrix is rendered
# via `Views::Controllers::VisualGroups::ImageMatrix` (always with
# status `"included"` for the show page).
module Views::Controllers::VisualGroups
  class Show < Views::FullPageBase
    prop :visual_group, VisualGroup
    prop :user, _Nilable(User)
    prop :filter, _Nilable(String)
    prop :pagination_data, _Nilable(PaginationData)
    prop :subset, _Array(_Tuple(::Image, _Nilable(_Boolean)))

    def view_template
      render_page_chrome

      render_content
      render_image_matrix
    end

    private

    def render_page_chrome
      add_show_title(@visual_group)
      add_edit_icons(@visual_group, @user)
      container_class(:full)
    end

    def render_content
      ContentPadded do
        render_description_and_approval
        hr
        if @filter
          render_filter_banner
        else
          render_counts_and_names
        end
      end
    end

    def render_description_and_approval
      p do
        strong { append_colon(:description.ti) }
        br
        trusted_html(@visual_group.description.t)
      end
      p do
        strong { append_colon(:approved.ti) }
        plain(@visual_group.approved.to_s)
      end
    end

    def render_filter_banner
      p do
        strong { plain("Showing definitional images for \"#{@filter}\"") }
        br
        Link(type: :get, name: "Show All Definitional Images",
             target: visual_group_path(@visual_group))
      end
    end

    def render_counts_and_names
      p do
        count = @visual_group.image_count("included")
        plain(:visual_group_count_included.t(count: count))
      end
      p do
        strong { append_colon(:visual_group_includes_names.t) }
        br
        render_distinct_name_links
      end
    end

    def render_distinct_name_links
      @visual_group.distinct_names.each do |name|
        Link(type: :get, name: name.text_name,
             target: visual_group_path(@visual_group,
                                       filter: name.text_name)) do
          trusted_html(name.format_name(@user).t)
        end
        br
      end
    end

    def render_image_matrix
      render(ImageMatrix.new(
               user: @user, visual_group: @visual_group,
               subset: @subset, status: "included",
               pagination_data: @pagination_data
             ))
    end
  end
end
