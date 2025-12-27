# frozen_string_literal: true

module Components
  # Component for rendering authors and editors metadata on show pages.
  #
  # Displays authors and editors with appropriate links for requesting
  # authorship credit or reviewing authors (for admins).
  #
  # @example For description objects
  #   render(Components::AuthorsAndEditors.new(
  #     obj: @name_description,
  #     versions: @versions,
  #     user: @user
  #   ))
  #
  # @example For non-description versioned objects
  #   render(Components::AuthorsAndEditors.new(
  #     obj: @name,
  #     versions: @versions,
  #     user: @user
  #   ))
  #
  class AuthorsAndEditors < Base
    prop :obj, _Any # Any object with type_tag
    prop :versions, _Union(Array, ActiveRecord::Associations::CollectionProxy),
         default: -> { [] }
    prop :user, _Nilable(User)

    def view_template
      type = @obj.type_tag

      authors, editors = if description_object?(type)
                           description_authors_and_editors
                         else
                           non_description_authors_and_editors
                         end

      p do
        trusted_html(authors)
        br
        trusted_html(editors)
      end
    end

    private

    def description_object?(type)
      /description/.match?(type.to_s)
    end

    # Renders authors and editors for description objects
    def description_authors_and_editors
      authors_list = @obj.authors
      editors_list = @obj.editors
      is_admin = @user && @obj.is_admin?(@user)
      is_author = @user && authors_list.include?(@user)

      authors = user_list(:show_name_description_author, authors_list)
      editors = user_list(:show_name_description_editor, editors_list)

      if is_admin
        authors = authors_with_review_link(authors)
      elsif !is_author
        authors = authors_with_request_link(authors)
      end

      [authors, editors]
    end

    def authors_with_review_link(authors)
      return authors unless authors

      authors + safe_nbsp + link_to(
        "(#{:review_authors_review_authors.t})",
        description_authors_path(id: @obj.id, type: @obj.type_tag)
      )
    end

    def authors_with_request_link(authors)
      return authors unless authors

      authors + safe_nbsp + link_to(
        "(#{:review_authors_review_authors.t})",
        description_authors_path(id: @obj.id, type: @obj.type_tag)
      )
    end

    # Renders authors and editors for non-description objects
    def non_description_authors_and_editors
      type = @obj.type_tag
      versions = @versions || []

      editor_ids = versions.map(&:user_id).uniq - [@obj.user_id]
      editors_list = User.where(id: editor_ids).to_a

      authors = user_list(:"show_#{type}_creator", [@obj.user])
      editors = user_list(:"show_#{type}_editor", editors_list)

      [authors, editors]
    end
  end
end
