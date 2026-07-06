# frozen_string_literal: true

# Action template for
# `Names::EolData::ExpandedReviewController#show`. Renders summary
# counts + a striped list of names with per-name image / description
# counts. `@data` is an `EolData` PORO (duck-typed via the methods
# called below).
class Views::Controllers::Names::EolData::ExpandedReview::Show <
  Views::FullPageBase
  prop :data, _Interface(:name_count, :total_image_count,
                         :total_description_count, :names,
                         :has_images?, :image_count,
                         :has_descriptions?, :description_count)

  def view_template
    add_page_title(:eol_expanded_review_title.t)
    render_summary
    render_name_rows
  end

  private

  def render_summary
    p do
      plain(
        [
          :eol_expanded_review_count.t(count: @data.name_count),
          :eol_expanded_review_total_image_count.t(
            count: @data.total_image_count
          ),
          :eol_expanded_review_total_description_count.t(
            count: @data.total_description_count
          )
        ].join(", ")
      )
    end
  end

  def render_name_rows
    odd_or_even = 0
    @data.names.each do |n|
      odd_or_even = 1 - odd_or_even
      render_name_row(n, odd_or_even)
    end
  end

  def render_name_row(name, odd_or_even)
    div(class: "ListLine#{odd_or_even} py-10px") do
      plain(name.display_name(current_user))
      br
      render_image_count_line(name.id) if @data.has_images?(name.id)
      render_description_count_line(name.id) \
        if @data.has_descriptions?(name.id)
    end
  end

  def render_image_count_line(id)
    plain(
      :eol_expanded_review_image_count.t(
        count: @data.image_count(id)
      )
    )
    br
  end

  def render_description_count_line(id)
    plain(
      :eol_expanded_review_description_count.t(
        count: @data.description_count(id)
      )
    )
  end
end
