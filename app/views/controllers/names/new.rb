# frozen_string_literal: true

# Action template for `NamesController#new`. Sets the new-page
# chrome and delegates to the `Names::Form` Phlex form.
module Views::Controllers::Names
  class New < Views::FullPageBase
    prop :name, ::Name
    prop :user, _Nilable(::User), default: nil
    prop :name_string, _Nilable(String), default: nil
    prop :approved_rank, _Nilable(String), default: nil

    def view_template
      add_new_title(:create_object, :NAME)
      add_context_nav(Tab::Name::FormNew.new)

      render(Form.new(
               @name, user: @user, name_string: @name_string,
                      approved_rank: @approved_rank
             ))
    end
  end
end
