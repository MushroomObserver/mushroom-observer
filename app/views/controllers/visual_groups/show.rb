# frozen_string_literal: true

# Action view for `visual_groups#show`. Replaces the
# `show.html.erb`. The image matrix is rendered via
# `Views::Controllers::VisualGroups::ImageMatrix` (always with status
# `"included"` for the show page).
module Views::Controllers::VisualGroups
  class Show < Views::Base
    prop :visual_group, VisualGroup
    prop :user, _Nilable(User)
    prop :filter, _Nilable(String)
    prop :pagination_data, _Nilable(PaginationData)
    prop :subset, _Array(_Any)

    def view_template
      add_show_title(@visual_group)
      add_edit_icons(@visual_group, @user)
      container_class(:full)

      render_top_nav
      render_description_and_approval
      hr
      if @filter
        render_filter_banner
      else
        render_counts_and_names
      end
      render(ImageMatrix.new(
               user: @user, visual_group: @visual_group,
               subset: @subset, status: "included",
               pagination_data: @pagination_data
             ))
      render_bottom_nav
    end

    private

    def render_top_nav
      p { render_nav_links }
    end

    def render_bottom_nav
      p { render_nav_links }
    end

    def render_nav_links
      link_to(:visual_group_edit.t, edit_visual_group_path(@visual_group))
      plain(" | ")
      link_to(:visual_group_index.t,
              visual_model_visual_groups_path(@visual_group.visual_model))
    end

    def render_description_and_approval
      p do
        strong { plain("#{:DESCRIPTION.t}:") }
        br
        plain(@visual_group.description.to_s)
      end
      p do
        strong { plain("#{:APPROVED.t}:") }
        whitespace
        plain(@visual_group.approved.to_s)
      end
    end

    def render_filter_banner
      strong { plain("Showing definitional images for \"#{@filter}\"") }
      br
      link_to("Show All Definitional Images",
              visual_group_path(@visual_group))
    end

    def render_counts_and_names
      p do
        count = @visual_group.image_count("included")
        plain(:visual_group_count_included.t(count: count))
      end
      p do
        strong { plain("#{:visual_group_includes_names.t}:") }
        br
        render_distinct_name_links
      end
    end

    def render_distinct_name_links
      @visual_group.distinct_names.each do |name|
        link_to(name[0],
                visual_group_path(@visual_group, filter: name[0]))
        br
      end
    end
  end
end
