# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Comments
  class CommentItemTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @comment = comments(:minimal_unknown_obs_comment_1)
      controller.instance_variable_set(:@user, @user)
    end

    # ---- structure --------------------------------------------------

    def test_inner_content_only_no_outer_wrapper
      # CommentItem's contract: emit ONLY the inner row + optional
      # trailing clearfix. The `.list-group-item.comment#dom_id`
      # wrapper is the caller's responsibility (ListGroup#item or
      # CommentRow). A wrapper accidentally appearing here would
      # double-wrap inside the panel's list group.
      html = render_item

      assert_no_html(html, ".list-group-item")
      assert_html(html, "div.row")
    end

    def test_renders_summary_and_body
      # `.comment-summary` carries the headline; `.comment-body`
      # carries the full Textile-rendered comment text.
      html = render_item

      assert_html(html, ".comment-summary",
                  text: @comment.summary)
      assert_html(html, ".comment-body")
    end

    def test_omits_comment_body_when_blank
      blank_body_comment = ::Comment.create!(target: @comment.target,
                                             user: @user,
                                             summary: "Just a headline")

      html = render_item(comment: blank_body_comment)

      assert_no_html(html, ".comment-body")
    end

    # ---- editable=true author + mod links --------------------------

    def test_editable_renders_user_link_and_mod_links
      # With editable=true the author cell shows a real UserLink
      # (selector hook `user_link_<id>`) and the row gains a
      # `data-user-specific="<author_id>"` mod-links span — the
      # site-wide CSS rule hides this span for everyone but the
      # author + admins.
      html = render_item(editable: true)

      assert_html(html, "a.user_link_#{@comment.user.id}")
      assert_html(html, "span[data-user-specific='#{@comment.user.id}']")
    end

    def test_not_editable_renders_plain_author_text
      # editable=false → no UserLink, just `unique_text_name` text,
      # and no mod-links wrapper span at all.
      html = render_item(editable: false)

      assert_no_html(html, "a.user_link_#{@comment.user.id}")
      assert_no_html(html, "[data-user-specific]")
      assert_includes(html, @comment.user.unique_text_name)
    end

    # ---- show_name target heading (comments-index mode) ------------

    def test_show_name_renders_target_link_and_type_label
      # show_name=true is the comments-index shape: each row needs
      # a header naming the target it belongs to.
      html = render_item(show_name: true)

      assert_html(html, "h4 a[href*='#{@comment.target.id}']")
      assert_includes(html, @comment.target.class.name.to_sym.t)
    end

    def test_show_name_false_omits_target_heading
      html = render_item(show_name: false)

      assert_no_html(html, "h4")
    end

    def test_show_name_with_deleted_target_falls_back_to_deleted_text
      # `target_name_link` and `target_type` are wrapped in
      # `rescue StandardError` so a comment outliving its target
      # (deleted observation, etc.) still renders in the comments
      # index. Stub the target to raise on the access path the
      # heading uses.
      raising_target = ::Object.new
      def raising_target.user_unique_format_name(*)
        raise(StandardError.new("target gone"))
      end

      def raising_target.class
        raise(StandardError.new("target gone"))
      end
      @comment.define_singleton_method(:target) { raising_target }

      html = render_item(show_name: true)

      assert_includes(html, :comment_list_deleted.t)
      assert_includes(html, :runtime_object_deleted.to_s)
    end

    # ---- avatar -----------------------------------------------------

    def test_avatar_image_rendered_when_user_has_image
      author = users(:mary)
      # Give the author an image so the avatar branch fires.
      author.update!(image: images(:in_situ_image))
      author_comment = ::Comment.create!(target: @comment.target,
                                         user: author,
                                         summary: "with avatar")

      html = render_item(comment: author_comment)

      # `.user-image-sizer` is the wrapper the legacy ERB used —
      # also asserted as the marker for the avatar branch.
      assert_html(html, ".user-image-sizer img")
      assert_html(html, "img[data-role='link']",
                  attribute: { "data-url" =>
                                 routes.user_path(author.id) })
    end

    def test_no_avatar_when_user_has_no_image
      author_no_image = users(:zero_user)
      author_no_image.update!(image: nil) if author_no_image.image_id
      noavatar_comment = ::Comment.create!(target: @comment.target,
                                           user: author_no_image,
                                           summary: "no avatar")

      html = render_item(comment: noavatar_comment)

      assert_no_html(html, ".user-image-sizer")
    end

    private

    def render_item(comment: @comment, user: @user, editable: false,
                    show_name: false)
      render(CommentItem.new(comment: comment, user: user,
                             editable: editable, show_name: show_name))
    end
  end
end
