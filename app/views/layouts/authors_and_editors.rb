# frozen_string_literal: true

module Views::Layouts
  # Authors + editors metadata block rendered on show pages. Two
  # shapes: description-object pages show the authors list with a
  # `request authorship` link (or the admin-only `review authors`
  # link); other versioned object pages (`Name`, `Location`,
  # `GlossaryTerm`) show editors with similar wiring.
  class AuthorsAndEditors < Views::Base
    # Concrete callers are `Description` (`NameDescription` and
    # `LocationDescription` subclasses), `Name`, `Location`, and
    # `GlossaryTerm`. Duck-typed via `_Interface(:type_tag)` so
    # tests can substitute lightweight stubs that don't carry the
    # full AR object graph the description / non-description
    # branches each consume.
    prop :obj, _Interface(:type_tag)
    # The view uses `versions.filter_map(&:user)`, so the prop only
    # has to know each entry responds to `#user`. Callers pass a real
    # Array (`@versions.to_a` at the render site) — the AR-association
    # CollectionProxy isn't an `Array`, so passing it raw would fail
    # the type check.
    prop :versions, _Array(_Interface(:user))
    prop :user, _Nilable(::User)

    def view_template
      type = @obj.type_tag

      if description_object?(type)
        description_authors_and_editors
      else
        non_description_authors_and_editors
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

      p do
        render_user_list(:show_name_description_author, authors_list) do
          render_authors_link if is_admin || !is_author
        end
        br
        render_user_list(:show_name_description_editor, editors_list)
      end
    end

    def render_authors_link
      whitespace
      a(href: description_authors_path(id: @obj.id, type: @obj.type_tag)) do
        plain("(#{:review_authors_review_authors.t})")
      end
    end

    # Renders authors and editors for non-description objects.
    # Reads editors from `versions.map(&:user)` — the host page's
    # `show_includes` scope eager-loads `{ versions: :user }`, so
    # no DB queries here.
    def non_description_authors_and_editors
      type = @obj.type_tag
      editors_list = @versions.filter_map(&:user).uniq - [@obj.user]

      p do
        render_user_list(:"show_#{type}_creator", [@obj.user])
        br
        render_user_list(:"show_#{type}_editor", editors_list)
      end
    end

    # Render a list of users on one line. Renders nothing if user list
    # empty. Accepts optional block to append content after the list.
    #
    # Examples:
    #   render_user_list(:show_name_description_author, authors)
    #   render_user_list(:show_name_description_editor, editors)
    #
    # With block:
    #   render_user_list(:show_name_description_author, authors) do
    #     a(href: some_path) { plain "(review)" }
    #   end
    def render_user_list(title, users = [])
      return unless users&.any?

      plain(user_list_title(title, users))
      render_user_links(users)
      yield if block_given?
    end

    def user_list_title(title, users)
      title_text = users.size > 1 ? title.to_s.pluralize.to_sym.t : title.t
      "#{title_text}: "
    end

    def render_user_links(users)
      users.each_with_index do |user, index|
        name = user.is_a?(Integer) ? nil : user&.legal_name
        render_user_link(user, name)
        plain(", ") unless index == users.size - 1
      end
    end

    # Wrap user name in link to show_user.
    def render_user_link(user, name = nil)
      render(Components::Link::User.new(user: user, name: name))
    end
  end
end
