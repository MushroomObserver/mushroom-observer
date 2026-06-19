# frozen_string_literal: true

# Site-wide comments index — the searchable / paginated listing
# linked from `comments?by_user=…`, `comments?for_user=…`, and the
# "and N more →" link at the bottom of a truncated
# `CommentsForObject` panel. Each row is a `CommentRow` with
# `show_name: true` so the target each comment is attached to is
# labeled in the heading.
module Views::Controllers::Comments
  class Index < Views::FullPageBase
    prop :query, ::Query::Comments
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::Comment)
    prop :user, _Nilable(::User), default: nil

    def view_template
      container_class(:text_image)
      add_index_title(@query)
      # Sort table lives on the controller — single source of truth.
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)

      paginated_results { render_list }
    end

    private

    def render_list
      return unless @objects.any?

      div(class: "list-group") do
        @objects.each do |comment|
          # Editable on logged-out viewers matches the legacy
          # `controls: @user.nil?` semantics — leaving the
          # apparent inversion intact pending a separate review.
          render(CommentRow.new(comment: comment, user: @user,
                                show_name: true, editable: @user.nil?))
        end
      end
    end
  end
end
