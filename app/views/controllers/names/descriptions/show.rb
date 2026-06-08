# frozen_string_literal: true

# Action view for `names/descriptions#show`. Sets the chrome (title,
# edit-icons row, page width) and delegates the body to the three
# Phlex panels that own the description show-page.
module Views::Controllers::Names::Descriptions
  class Show < Views::Base
    prop :description, ::NameDescription
    prop :user, _Nilable(::User), default: nil
    # Controller always passes — no need for a default fallback.
    prop :versions, _Union(Array, ActiveRecord::Associations::CollectionProxy)
    prop :projects, _Nilable(_Array(::Project)), default: nil

    def view_template
      add_show_title(@description)
      add_edit_icons(@description, @user)
      container_class(:wide)

      render(Views::Controllers::Descriptions::DetailsAndAltsPanel.new(
               description: @description, user: @user,
               versions: @versions, projects: @projects, review: true
             ))
      render(Views::Controllers::Descriptions::NotesPanels.new(
               description: @description
             ))
      render(Views::Controllers::Descriptions::AuthorsAndEditorsPanel.new(
               description: @description, user: @user, versions: @versions
             ))
      render(Components::ObjectFooter.new(
               user: @user, obj: @description, versions: @versions
             ))
    end
  end
end
