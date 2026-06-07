# frozen_string_literal: true

# Sibling of `DisplayNameBriefAuthorsLink` — same pattern but
# without authority abbreviations (`user_display_name_without_authors`).
# Used for the preferred-synonym slot in the obs-title chain.
module Views::Controllers::Observations
  class DisplayNameWithoutAuthorsLink < Views::Base
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
        trusted_html(@name.user_display_name_without_authors(@user).t)
      end
    end
  end
end
