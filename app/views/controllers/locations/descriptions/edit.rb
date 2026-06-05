# frozen_string_literal: true

module Views::Controllers::Locations::Descriptions
  class Edit < Views::Base
    prop :description, ::LocationDescription
    prop :user, _Nilable(::User), default: nil
    prop :licenses, _Array(_Tuple(String, Integer)), default: -> { [] }
    # Merge-flow locals — nil on a regular edit.
    prop :merge, _Nilable(_Boolean), default: nil
    prop :old_desc_id, _Nilable(Integer), default: nil
    prop :delete_after, _Nilable(_Boolean), default: nil

    def view_template
      add_page_title(:edit_location_description_title.t(
                       name: @description.format_name
                     ))
      add_context_nav(::Tab::LocationDescription::FormEdit.new(
                        description: @description
                      ))

      render(Views::Controllers::Descriptions::Form.new(
               @description, licenses: @licenses, user: @user,
                             merge_opts: {
                               merge: @merge, old_desc_id: @old_desc_id,
                               delete_after: @delete_after
                             }
             ))
    end
  end
end
