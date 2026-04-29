# frozen_string_literal: true

# Form object backing the inline "Add target names" textarea on the
# project Names tab (#3991). One newline-separated string of name
# entries; the controller parses it into individual names.
class FormObject::ProjectTargetNamesAdd < FormObject::Base
  attribute :names, :string
end
