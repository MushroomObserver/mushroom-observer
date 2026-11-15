# frozen_string_literal: true

# `<a>` link to a Name's show page, with the display name rendered
# through textile (`.t.small_author`) so authority abbreviations
# get the small-caps treatment. Used in the obs-title chain
# (consensus name link, deprecated-synonym link, owner-preferred
# link).
module Views::Controllers::Observations
  class DisplayNameBriefAuthorsLink < Views::Base
    prop :name, ::Name
    prop :user, _Nilable(::User), default: nil
    prop :attributes, _Hash(Symbol, _Any?), :**

    def view_template
      Link(type: :get, name: @name.text_name,
           target: name_path(id: @name.id), **@attributes) do
        trusted_html(@name.display_name_brief_authors(@user).
                     t.small_author)
      end
    end
  end
end
