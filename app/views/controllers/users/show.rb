# frozen_string_literal: true

module Views::Controllers::Users
  # User show — left column profile + stats, right column best-images
  # carousel.
  class Show < Views::Base
    prop :show_user, ::User
    prop :life_list, ::Checklist::ForUser
    # Pre-computed in the controller (so the `Language.pluck(...)`
    # query stays out of the view). Field-keyed paths are built
    # inside `UserStats` itself via the Phlex route helpers.
    prop :user_stats_rows, _Array(::Hash), default: -> { [] }
    prop :best_images, _Array(_Nilable(::Image)), default: -> { [] }

    def view_template
      add_show_title(@show_user)
      add_pager_for(@show_user)
      add_context_nav(::Tab::User::ShowActions.new)
      container_class(:full)
      column_classes(:six_even)

      div(class: "row") do
        div(class: content_for(:left_columns)) { render_left_column }
        div(class: content_for(:right_columns)) { render_right_column }
      end
    end

    private

    def render_left_column
      render(Show::Profile.new(show_user: @show_user, user: current_user,
                               life_list: @life_list))
      return unless @show_user.contribution.positive?

      return if @user_stats_rows.empty?

      render(Show::UserStats.new(show_user: @show_user,
                                 rows: @user_stats_rows,
                                 name: @show_user.login))
    end

    def render_right_column
      return unless @best_images.length.positive?

      render(::Components::ImageGallery.new(
               object: @show_user,
               images: @best_images,
               title: :show_user_observations_by.t(name: @show_user.login),
               panel_id: "user_best_images"
             ))
    end
  end
end
