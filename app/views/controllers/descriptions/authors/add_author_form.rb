# frozen_string_literal: true

# Tiny form rendered in the "other users" section of the
# description authors-review page: a user autocompleter +
# "Add Author" submit button. Selecting a user from the
# autocompleter populates the hidden `add_author[add]` field
# with the user's id; submitting POSTs to
# `description_authors_path` which dispatches to
# `Descriptions::AuthorsController#create`, adding the user as
# an author.
module Views::Controllers::Descriptions::Authors
  class AddAuthorForm < Components::ApplicationForm
    def initialize(model, object:, **)
      @object = object
      super(model, **)
    end

    def view_template
      div(class: "d-flex align-items-end gap-2 mt-2") do
        autocompleter_field(
          :user,
          type: :user,
          label: false,
          placeholder: :review_authors_add_author.t,
          inline: true,
          size: 40
        )
        submit(:review_authors_add_author.t)
      end
    end

    private

    def form_action
      url_for(
        controller: "descriptions/authors", action: :create,
        id: @object.id, type: @object.type_tag, only_path: true
      )
    end
  end
end
