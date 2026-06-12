# frozen_string_literal: true

# Action view for `names/descriptions#edit`. Sets the chrome and
# renders the shared description form, threading the merge-flow
# locals through to the form.
module Views::Controllers::Names::Descriptions
  class Edit < Views::Base
    prop :description, ::NameDescription
    prop :user, _Nilable(::User), default: nil
    prop :licenses, _Array(_Tuple(String, Integer)), default: -> { [] }
    # Merge-flow locals — populated when this edit is reached via a
    # "merge two descriptions" redirect. Nil on a regular edit.
    prop :merge, _Nilable(_Boolean), default: nil
    prop :old_desc_id, _Nilable(Integer), default: nil
    prop :delete_after, _Nilable(_Boolean), default: nil

    def view_template
      add_page_title(:edit_name_description_title.t(
                       name: @description.format_name
                     ))
      add_context_nav(::Tab::NameDescription::FormEdit.new(
                        description: @description,
                        admin: @description.is_admin?(@user) || in_admin_mode?
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
