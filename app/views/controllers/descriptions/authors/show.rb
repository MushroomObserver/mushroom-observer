# frozen_string_literal: true

# Action view for `descriptions/authors#show`. Admins of a description
# manage its author roster here: existing authors get a destroy
# button beside their name, plus a user-autocompleter + "Add Author"
# submit at the bottom (`AddAuthorForm`).
module Views::Controllers::Descriptions::Authors
  class Show < Views::Base
    prop :object, ::AbstractModel
    # Callers pass `@description.authors.to_a` — the controller
    # converts the has_many-through CollectionProxy at the boundary.
    prop :authors, _Array(::User)

    def view_template
      type = @object.type_tag

      add_page_title(:review_authors_title.t(name: @object.format_name))
      add_context_nav(::Tab::Description::AuthorReview.new(object: @object))

      trusted_html(:review_authors_note.tp) if type == :name_description

      render_authors_block(type)
      render_other_users_block
    end

    private

    def render_authors_block(type)
      p do
        plain(:review_authors_authors.t)
        br
        @authors.each { |u| render_author_row(u, type) }
      end
    end

    def render_author_row(user, type)
      render(Components::Link::Object::User.new(user: user))
      plain(" | ")
      render(Components::CrudButton::Delete.new(
               name: :review_authors_remove_author.t,
               target: description_authors_path(
                 id: @object.id, type: type, remove: user.id
               ),
               btn: nil
             ))
      br
    end

    def render_other_users_block
      p do
        plain(:review_authors_other_users.t)
        render(AddAuthorForm.new(::FormObject::AddAuthor.new,
                                 object: @object))
      end
    end
  end
end
