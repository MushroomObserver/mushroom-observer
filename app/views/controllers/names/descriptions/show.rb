# frozen_string_literal: true

# Action view for `names/descriptions#show`. Sets the chrome and
# lays out the description show-page panels in two columns: this
# description's content on the left, the parent Name's other
# descriptions + new-draft UI on the right (#5527 review).
module Views::Controllers::Names::Descriptions
  class Show < Views::FullPageBase
    prop :description, ::NameDescription
    prop :user, _Nilable(::User), default: nil
    # Controller always passes — no need for a default fallback.
    prop :versions, _Array(_Interface(:user_id))
    prop :incoming_project, _Nilable(::Project), default: nil

    def view_template
      add_show_title(@description)
      add_edit_icons(@description, @user)
      container_class(:wide)
      column_classes(:six_even)

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
      render(Views::Controllers::Descriptions::DetailsPanel.new(
               description: @description, user: @user, review: true
             ))
      render(Views::Controllers::Descriptions::NotesPanels.new(
               description: @description
             ))
      render(Views::Controllers::Descriptions::AuthorsAndEditorsPanel.new(
               description: @description, user: @user, versions: @versions
             ))
    end

    def render_right_column
      if @versions.size > 1
        render(Views::Controllers::Versions::Previous.new(
                 obj: @description, versions: @versions
               ))
      end
      render(Views::Controllers::Descriptions::OtherDescriptionsPanel.new(
               description: @description, user: @user,
               incoming_project: @incoming_project
             ))
    end
  end
end
