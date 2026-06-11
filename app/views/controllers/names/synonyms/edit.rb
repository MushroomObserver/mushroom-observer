# frozen_string_literal: true

# Action template for `Names::SynonymsController#edit`. Page-chrome
# + the `Names::Synonyms::Form` Phlex form (which owns the
# existing / proposed / members fields layout).
class Views::Controllers::Names::Synonyms::Edit < Views::Base
  prop :name, ::Name
  prop :list_members, _Nilable(String), default: nil
  prop :deprecate_all, _Boolean, default: true
  prop :proposed_synonyms, _Nilable(_Array(::Name)), default: nil
  prop :new_names, _Nilable(_Array(String)), default: nil

  def view_template
    add_page_title(
      :name_change_synonyms_title.t(name: @name.display_name)
    )
    add_context_nav(Tab::Name::FormsReturn.new(name: @name))
    container_class(:text_image)

    render(Views::Controllers::Names::Synonyms::Form.new(
             name: @name,
             synonym_members: @list_members,
             deprecate_all: @deprecate_all,
             current_synonyms: @name.synonyms,
             proposed_synonyms: @proposed_synonyms,
             new_names: @new_names
           ))
  end
end
