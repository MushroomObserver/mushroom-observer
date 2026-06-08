# frozen_string_literal: true

# FormObject backing the "add an author" form on the description
# authors-review page. The form has a single user-autocompleter
# field whose selected user id submits as `params[:add_author][:user]`.
class FormObject::AddAuthor < FormObject::Base
  attribute :user, :integer
end
