# frozen_string_literal: true

module Views::Controllers::Locations::Descriptions::Permissions
  class Edit < Views::Base
    prop :description, ::LocationDescription
    prop :groups, _Array(::UserGroup)
    # `@data` is `nil` on a fresh edit; populated on update-redo.
    prop :data, _Nilable(Array), default: nil

    def view_template
      add_page_title(@description.format_name.t)
      add_context_nav(::Tab::LocationDescription::FormPermissions.new(
                        description: @description
                      ))

      render(Views::Controllers::Descriptions::Permissions::Form.new(
               description: @description, groups: @groups, data: @data
             ))
    end
  end
end
