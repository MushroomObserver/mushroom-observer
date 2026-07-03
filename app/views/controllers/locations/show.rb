# frozen_string_literal: true

module Views::Controllers::Locations
  # Location show page — map + general description + comments on the
  # left, coordinates / notes / alt-descriptions / authorship on the
  # right, version footer at the bottom.
  class Show < Views::FullPageBase
    prop :location, ::Location
    prop :description, _Nilable(::LocationDescription), default: nil
    prop :versions, _Array(_Interface(:user_id))
    prop :comments, _Nilable(_Array(::Comment)), default: nil
    prop :projects, _Array(::Project)

    def view_template
      register_page_chrome
      container_class(:full)
      column_classes(:seven_five)

      p { :show_location_hidden.l } if @location.hidden

      div(class: "row") { render_main_columns }
      div(class: "mt-3") do
        render(::Views::Layouts::ObjectFooter.new(
                 user: current_user, obj: @location, versions: @versions.to_a
               ))
      end
    end

    private

    def register_page_chrome
      add_show_title(@location)
      return unless current_user

      add_edit_icons(@location, current_user)
      add_interest_icons(current_user, @location)
      add_pager_for(@location)
    end

    def render_main_columns
      div(class: content_for(:left_columns)) { render_left_column }
      div(class: content_for(:right_columns)) { render_right_column }
    end

    def render_left_column
      div(class: "mb-5") do
        Map(objects: [@location])
      end
      render(Show::GeneralDescriptionPanel.new(
               location: @location, description: @description
             ))
      render(Views::Controllers::Comments::CommentsForObject.new(
               object: @location, comments: @comments.to_a, user: current_user,
               editable: current_user.present?, limit: 2
             ))
    end

    def render_right_column
      render(Show::Coordinates.new(location: @location))
      render(Show::Notes.new(location: @location))
      render(Show::AltDescriptionsPanel.new(
               user: current_user, object: @location, projects: @projects
             ))
      render(Show::Footer.new(location: @location, versions: @versions.to_a))
    end
  end
end
