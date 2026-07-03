# frozen_string_literal: true

# Warning alert listing alternate-spelling Name candidates,
# shown on the Names index when a pattern search returns zero
# matches AND the controller fed back a non-empty list of
# alt-spellings (`@name_suggestions = Name.suggest_alternate_spellings(...)`).
class Views::Controllers::Names::Index::NameSuggestionsAlert < Views::Base
  prop :names, _Array(::Name)
  prop :user, _Nilable(::User), default: nil

  def view_template
    Alert(level: :warning) do
      div { plain(:list_observations_alternate_spellings.t) }
      ul(type: "none") do
        @names.sort_by(&:sort_name).each do |name|
          li do
            a(href: name_path(name.id)) do
              trusted_html(name.user_display_name(@user).t)
            end
          end
        end
      end
    end
  end
end
