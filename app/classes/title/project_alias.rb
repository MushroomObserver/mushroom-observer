# frozen_string_literal: true

# Page heading + browser tab title — `name` alone ("0", "NJW") isn't
# self-explanatory out of context, so both lead with the type label.
class Title::ProjectAlias < Title
  def page_title(_user = nil)
    "#{:project_alias.ti}: \"#{@object.name}\""
  end
  alias document_title page_title
end
