# frozen_string_literal: true

# Form object backing the inline "Add members" textarea on the
# project Members tab. One newline-separated string of user
# identifiers; the controller parses it into individual candidates.
class FormObject::ProjectMembersAdd < FormObject::Base
  attribute :candidates, :string
end
