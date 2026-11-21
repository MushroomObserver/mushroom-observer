# frozen_string_literal: true

# Action view for `locations/descriptions#show`. Sets the chrome and
# lays out the description show-page panels in two columns: the
# description's content (general notes + authors/editors) on the
# left, the Detail panel + the parent Location's other descriptions
# on the right (#5527 review).
module Views::Controllers::Locations::Descriptions
  class Show < Views::FullPageBase
    prop :description, ::LocationDescription
    prop :user, _Nilable(::User), default: nil
    # Controller always passes — no need for a default fallback.
    prop :versions, _Array(_Interface(:user_id))

    def view_template
      add_show_title(@description)
      add_edit_icons(@description, @user)
      add_pager_for(@description)
      container_class(:wide)
      column_classes(:six)

      Row { render_columns }
      render(Views::Layouts::ObjectFooter.new(
               user: @user, obj: @description, versions: @versions
             ))
    end

    private

    def render_columns
      div(class: content_for(:left_columns)) { render_left_column }
      div(class: content_for(:right_columns)) { render_right_column }
    end

    def render_left_column
      render(Views::Controllers::Descriptions::NotesPanels.new(
               description: @description
             ))
      render(Views::Controllers::Descriptions::AuthorsAndEditorsPanel.new(
               description: @description, user: @user, versions: @versions
             ))
    end

    def render_right_column
      render(Views::Controllers::Descriptions::DetailsPanel.new(
               description: @description, user: @user
             ))
      if @versions.size > 1
        render(Views::Controllers::Versions::Previous.new(
                 obj: @description, versions: @versions
               ))
      end
      render(Views::Controllers::Descriptions::OtherDescriptionsPanel.new(
               description: @description, user: @user
             ))
    end
  end
end
