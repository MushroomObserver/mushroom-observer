# frozen_string_literal: true

# Action view for `names/descriptions/permissions#edit`. Sets the
# chrome and renders the shared permissions form.
module Views::Controllers::Names::Descriptions::Permissions
  class Edit < Views::FullPageBase
    prop :description, ::NameDescription
    prop :groups, _Array(::UserGroup)
    # `@data` is `nil` on a fresh edit; populated on update-redo.
    prop :data, _Nilable(Array), default: nil

    def view_template
      add_page_title(@description.format_name.t)
      add_context_nav(::Tab::NameDescription::FormPermissions.new(
                        description: @description
                      ))

      render(Views::Controllers::Descriptions::Permissions::Form.new(
               description: @description, groups: @groups, data: @data
             ))
    end
  end
end
