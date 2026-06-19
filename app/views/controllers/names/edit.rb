# frozen_string_literal: true

# Action template for `NamesController#edit`. Sets the edit-page
# chrome and delegates to the `Names::Form` Phlex form.
module Views::Controllers::Names
  class Edit < Views::FullPageBase
    prop :name, ::Name
    prop :user, _Nilable(::User), default: nil
    prop :name_string, _Nilable(String), default: nil
    prop :misspelling, _Boolean, default: false
    prop :correct_spelling, _Nilable(String), default: nil

    def view_template
      add_edit_title(@name, user: @user)
      add_context_nav(
        Tab::Name::FormEdit.new(name: @name, q_param: q_param)
      )

      render(Form.new(
               @name, user: @user, name_string: @name_string,
                      misspelling: @misspelling,
                      correct_spelling: @correct_spelling
             ))
    end
  end
end
