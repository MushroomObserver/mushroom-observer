# frozen_string_literal: true

# Action template for `NamesController#edit`. Sets the edit-page
# chrome and delegates to the `Names::Form` Phlex form.
module Views::Controllers::Names
  class Edit < Views::FullPageBase
    prop :name, ::Name
    prop :user, ::User
    prop :name_string, _Nilable(String), default: nil
    prop :misspelling, _Boolean, default: false
    prop :correct_spelling, _Nilable(String), default: nil

    def view_template
      add_edit_title(@name, user: @user)
      add_context_nav(
        Tab::Name::FormEdit.new(
          name: @name, index_filter: index_filter(:Name)
        )
      )

      render(Form.new(
               @name, user: @user, name_string: @name_string,
                      misspelling: @misspelling,
                      correct_spelling: @correct_spelling, turbo: true
             ))
    end
  end
end
