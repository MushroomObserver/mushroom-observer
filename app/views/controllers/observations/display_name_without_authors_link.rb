# frozen_string_literal: true

# Sibling of `DisplayNameBriefAuthorsLink` — same pattern but
# without authority abbreviations (`display_name_without_authors`).
# Used for the preferred-synonym slot in the obs-title chain.
module Views::Controllers::Observations
  class DisplayNameWithoutAuthorsLink < Views::Base
    prop :name, ::Name
    prop :user, _Nilable(::User), default: nil
    prop :attributes, _Hash(Symbol, _Any?), :**

    def view_template
      Link(type: :get, name: @name.text_name,
           target: name_path(id: @name.id), **@attributes) do
        trusted_html(@name.display_name_without_authors(@user).t)
      end
    end
  end
end
