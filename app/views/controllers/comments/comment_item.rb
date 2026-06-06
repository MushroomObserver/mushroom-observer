# frozen_string_literal: true

# One comment rendered as a `.list-group-item.comment` Bootstrap row.
# Used in two places:
#
# - **`CommentsForObject` panel** — the inner per-comment row inside
#   the comments-for-object Panel. `editable:` is whether the
#   viewer should see edit/destroy mod-links + a real author
#   UserLink (truthy on logged-in viewers); `show_name:` is false.
# - **`comments/index.html.erb`** — the site-wide searchable
#   comments index. `show_name: true` adds a heading with a link
#   to the comment's target.
#
# Also rendered indirectly via the `Comment` model's
# `after_create_commit` / `after_update_commit` Turbo-Stream
# broadcasts — those callbacks render this view to HTML and pass
# it as the broadcast payload, replacing the legacy
# `partial: "comments/comment"` lookup.
#
# Replaces `app/views/controllers/comments/_comment.erb`.
module Views::Controllers::Comments
  class CommentItem < Views::Base
    include Phlex::Rails::Helpers::ImageTag

    prop :comment, ::Comment
    prop :user, _Nilable(::User), default: nil
    # When true, render edit/destroy mod-links and a real author
    # UserLink. When false, the author shows as plain text and no
    # mod-links wrapper is emitted. The legacy ERB called this
    # prop `controls`; the rename keeps it clear that the flag is
    # about edit-affordance, not the comment's existence.
    prop :editable, _Boolean, default: false
    prop :show_name, _Boolean, default: false

    # Renders the inner content of a `.list-group-item.comment`
    # row. The wrapper itself is owned by the consumer:
    #
    # - `CommentsForObject` provides it via
    #   `ListGroup#item(class: "comment", id: dom_id(comment))`.
    # - The Comment model's `after_create_commit` broadcast wraps
    #   this view in `Components::ListGroupItem` before prepending
    #   to the list.
    # - `after_update_commit` broadcasts use `broadcast_update_to`
    #   with `target: "comment_<id>"`, which replaces this inner
    #   content in place — the existing wrapper element stays.
    #
    # NOTE: intentionally no `data-controller="section-update"`
    # here. The submitter's modal is closed directly by the
    # CommentsController turbo_stream response. If wired here, a
    # second-window Action Cable broadcast could close a modal
    # the viewing user has open, losing in-progress form input.
    def view_template
      div(class: "row") do
        render_main_column
        render_avatar_column
      end
      # Trailing clearfix only if the avatar column floated.
      div(class: "clearfix") if @comment.user.image_id
    end

    private

    def render_main_column
      div(class: "col-xs-12 col-sm-9 col-lg-10") do
        render_target_heading if @show_name
        render_summary
        render_comment_info
        render_comment_body if @comment.comment.present?
      end
    end

    def render_summary
      div(class: "comment-summary font-weight-bold") do
        trusted_html(@comment.summary.tl)
      end
    end

    def render_comment_body
      div(class: "clearfix")
      div(class: "p-2 comment-body") do
        trusted_html(@comment.comment.tpl)
      end
    end

    # ---- target heading (comments-index "show_name" mode) ---------

    # `target_name_link` and `target_type` are wrapped in `rescue`
    # blocks in the legacy helper — a comment can outlive its
    # target (deleted observation, project, etc.), and the
    # comments-index list still needs to render the row. The
    # rescues swallow nil-target / missing-method errors and
    # substitute a "deleted" placeholder.
    def render_target_heading
      h4(class: "mt-0") do
        target_name_link
        whitespace
        target_type
      end
    end

    def target_name_link
      link_to(@comment.target.user_unique_format_name(@user).t,
              @comment.target.show_link_args)
    rescue StandardError
      plain(:comment_list_deleted.t)
    end

    def target_type
      span(class: "small") { plain(@comment.target.class.name.to_sym.t) }
    rescue StandardError
      plain(:runtime_object_deleted.to_s)
    end

    # ---- comment info row -----------------------------------------

    def render_comment_info
      div(class: "comment-info") do
        render_author_span
        render_mod_links_span if @editable
        render_timestamp
      end
    end

    def render_author_span
      span(class: "comment-author text-nowrap") do
        plain("#{:BY.t}: ")
        if @editable
          UserLink(user: @comment.user)
        else
          plain(@comment.user.unique_text_name)
        end
        plain(" ")
      end
    end

    # Two render contexts, two permission strategies:
    #
    # - Normal request — `@user` is the current viewer.
    #   `InlineModLinks` gates on `target.user == @user ||
    #   in_admin_mode?` so the links don't appear for non-authors.
    # - Action Cable broadcast — `@user` is nil. Fall back to
    #   `comment.user` so the gate passes; the markup ships
    #   unconditionally. The wrapping `[data-user-specific]`
    #   span teams up with the site-wide CSS rule (see
    #   `_user_specific_css.html.erb`) to hide it for everyone
    #   except the comment's author on the receiving end. Admins
    #   bypass the CSS so they still see mod links.
    def render_mod_links_span
      span(class: "text-nowrap",
           data: { user_specific: @comment.user.id }) do
        InlineModLinks(target: @comment,
                       user: @user || @comment.user, indent: false)
      end
    end

    def render_timestamp
      div(class: "float-sm-right text-nowrap small") do
        plain(@comment.created_at.web_time)
      end
    end

    # ---- avatar column --------------------------------------------

    def render_avatar_column
      div(class: "d-none d-sm-block col-sm-3 col-lg-2 text-center") do
        render_avatar_image if @comment.user.image_id
      end
    end

    def render_avatar_image
      div(class: "user-image-sizer") do
        image_tag(::Image.url(:thumbnail, @comment.user.image_id),
                  class: "img-fluid",
                  data: { role: "link",
                          url: user_path(@comment.user.id) })
      end
    end
  end
end
