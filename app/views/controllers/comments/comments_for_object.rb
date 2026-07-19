# frozen_string_literal: true

# Comments-for-object panel: the boxed list of comments shown on
# `observations/show`, `names/show`, `projects/show`,
# `locations/show`, `species_lists/show`, and the
# `comments/new` / `comments/edit` pages (via `_object.rb`).
#
# Renders a `Components::Panel` whose body is a flush
# `Components::ListGroup` of `CommentItem`s — wired to an Action
# Cable Turbo Stream from `[object, :comments]` so the
# `Comment` model's broadcast callbacks can prepend new rows,
# replace edited rows, and remove deleted rows in place.
#
# When `editable:` is truthy:
# - The heading carries a "+ Add comment" modal-link button.
# - Each `CommentItem` renders mod-links + a real author UserLink.
# - The footer shows an "and N more →" link when truncated.
module Views::Controllers::Comments
  class CommentsForObject < Views::Base
    include Phlex::Rails::Helpers::TurboStreamFrom
    include Phlex::Rails::Helpers::DOMID

    # `object` is whatever commentable model is being shown.
    # `Comment::ALL_TYPES` enumerates the polymorphic target set
    # (Observation, Name, Project, Location, SpeciesList,
    # LocationDescription, NameDescription); all inherit from
    # `AbstractModel`.
    prop :object, ::AbstractModel
    prop :comments, _Nilable(_Array(::Comment)), default: nil
    prop :user, _Nilable(::User), default: nil
    # When true, render the "+ Add comment" header link, per-row
    # mod-links, and the footer "and N more" link. Callers pass
    # `@user.present?` or a hardcoded false.
    prop :editable, _Boolean, default: false
    prop :limit, _Nilable(Integer), default: nil

    def view_template
      turbo_stream_from(@object, :comments)
      render(Components::Panel.new(
               panel_id: "comments_for_object"
             )) do |panel|
        panel.with_heading { plain(:comments.ti) }
        panel.with_heading_links { render_add_comment_link } if @editable
        panel.with_body(wrapper: false) { render_comments_list }
        panel.with_footer { render_and_more_link } if show_and_more_footer?
      end
    end

    private

    # `#comments` is the Action Cable broadcast target — the model
    # callbacks broadcast `[object, :comments]` with `target: "comments"`.
    def render_comments_list
      ListGroup(id: "comments", flush: true, class: "comments") do |list|
        visible_comments.each do |comment|
          list.item(class: "comment", id: dom_id(comment)) do
            render(CommentItem.new(comment: comment, user: @user,
                                   editable: @editable))
          end
        end
        list.empty { plain(:show_comments_no_comments_yet.t) }
      end
    end

    # ---- header "+ Add comment" link ------------------------------

    def render_add_comment_link
      Button(
        type: :modal,
        name: :show_comments_add_comment.l,
        target: new_comment_path(
          target: @object.id, type: @object.class.name
        ),
        modal_id: "comment",
        variant: :strip, icon: :add
      )
    end

    # ---- footer "and N more →" link -------------------------------

    def show_and_more_footer?
      @editable && @limit && and_more.positive?
    end

    def render_and_more_link
      link_to(:show_comments_and_more.t(num: and_more),
              comments_path(target: @object.id,
                            type: @object.class.name),
              class: "float-right")
    end

    # ---- comment list slicing ------------------------------------

    def visible_comments
      return @comments unless @limit && @comments

      @comments[0..(@limit - 1)]
    end

    def and_more
      return 0 unless @limit && @comments

      @comments.length - @limit
    end
  end
end
