# frozen_string_literal: true

# Tiny form rendered in the "other users" section of the
# description authors-review page: a user autocompleter +
# "Add Author" submit button. Submits `description_author[user]`
# (the typed/selected unique_text_name) to `description_authors_path`,
# which dispatches to `Descriptions::AuthorsController#create`,
# resolved via `User.lookup_unique_text_name`.
module Views::Controllers::Descriptions::Authors
  class AddAuthorForm < Components::ApplicationForm
    prop :object, ::AbstractModel

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
