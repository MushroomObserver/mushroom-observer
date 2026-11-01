# frozen_string_literal: true

# Backs Descriptions::Authors::AddAuthorForm. `user` is the typed/
# selected unique_text_name, resolved via User.lookup_unique_text_name
# -- not an id.
class FormObject::DescriptionAuthor < FormObject::Base
  attribute :user, :string
end
