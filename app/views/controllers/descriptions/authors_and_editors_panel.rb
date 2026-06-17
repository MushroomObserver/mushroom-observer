# frozen_string_literal: true

# Bottom panel on every description show page: authors + editors
# block (via `Views::Layouts::AuthorsAndEditors`) plus an optional
# license badge.
#
# Replaces the thin pre-Phlex `_show_description_authors_and_editors.erb`
# partial + its `DescriptionsHelper#show_description_authors_and_editors`
# composer.
module Views::Controllers::Descriptions
  class AuthorsAndEditorsPanel < Views::Base
    prop :description, ::Description
    prop :user, _Nilable(::User), default: nil
    prop :versions, _Array(_Interface(:user_id))

    def view_template
      div(class: "text-center") do
        render(Views::Layouts::AuthorsAndEditors.new(
                 obj: @description, versions: @versions, user: @user
               ))
        render_license_badge if @description.license
      end
    end

    private

    def render_license_badge
      render(Components::LicenseBadge.new(license: @description.license))
    end
  end
end
