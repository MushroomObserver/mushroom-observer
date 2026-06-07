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
    # No `default:` — `#initialize` always passes `attributes:`
    # (empty hash when no kwargs), so a default lambda would be
    # dead code (and a coverage gap).
    prop :attributes, _Hash(_Union(Symbol, String), _Any?)

    def initialize(name:, user: nil, **attributes)
      super(name: name, user: user, attributes: attributes)
    end

    def view_template
      link_to(name_path(id: @name.id), **@attributes) do
        trusted_html(@name.user_display_name_brief_authors(@user).
                     t.small_author)
      end
    end
  end
end
