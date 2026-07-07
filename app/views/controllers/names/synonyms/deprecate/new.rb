# frozen_string_literal: true

# Action template for `Names::Synonyms::DeprecateController#new`.
# Page-chrome + the `Names::Synonyms::Deprecate::Form` Phlex form
# (which renders the misspelling-correction guidance + the
# proposed-name field on top of suggest-corrections data).
class Views::Controllers::Names::Synonyms::Deprecate::New < Views::FullPageBase
  prop :name, ::Name
  prop :given_name, _Nilable(String), default: nil
  prop :misspelling, _Boolean, default: false
  prop :comment, _Nilable(String), default: nil
  prop :names, _Nilable(_Array(::Name)), default: nil
  prop :valid_names, _Nilable(_Array(::Name)), default: nil
  prop :suggest_corrections, _Boolean, default: false
  prop :parent_deprecated, _Nilable(::Name), default: nil

  def view_template
    add_page_title(
      :name_deprecate_title.t(name: @name.display_name(current_user))
    )
    add_context_nav(Tab::Name::FormsReturn.new(name: @name))

    render(Views::Controllers::Names::Synonyms::Deprecate::Form.new(
             name: @name,
             proposed_name: @given_name,
             is_misspelling: @misspelling,
             comment: @comment,
             names: @names,
             valid_names: @valid_names,
             suggest_corrections: @suggest_corrections,
             parent_deprecated: @parent_deprecated,
             user: current_user
           ))
  end
end
