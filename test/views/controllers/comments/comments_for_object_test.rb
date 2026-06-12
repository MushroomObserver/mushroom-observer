# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Comments
  class CommentsForObjectTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @observation = observations(:minimal_unknown_obs)
      @comments = ::Comment.where(target: @observation).order(:id).to_a
      controller.instance_variable_set(:@user, @user)
    end

    # ---- structural skeleton ---------------------------------------

    def test_renders_panel_with_comments_list_group_inside_body
      # Stable id `#comments_for_object` is the panel root (matches
      # the `assert_select` calls in controllers' show tests).
      # `#comments` is the inner list-group — also the Action Cable
      # broadcast target the `Comment` model writes to.
      html = render_panel

      assert_html(html, "#comments_for_object")
      assert_html(html, "#comments_for_object #comments.list-group")
      assert_html(html, "#comments_for_object #comments.list-group-flush")
    end

    def test_subscribes_to_action_cable_for_object_comments_stream
      # The `turbo_stream_from(object, :comments)` cable subscription
      # is what makes the model's `broadcast_prepend_to` /
      # `broadcast_update_to` callbacks reach the page.
      html = render_panel

      assert_html(html, "turbo-cable-stream-source")
    end

    # ---- editable header link --------------------------------------

    def test_editable_renders_add_comment_modal_link
      # Header link opens `comments/new` in a modal via the
      # `modal-toggle` Stimulus controller; selector class +
      # `data-controller` are the contract.
      html = render_panel(editable: true)

      assert_html(html,
                  "#comments_for_object " \
                  "a[data-controller='modal-toggle']")
      assert_html(html,
                  "a[href='#{routes.new_comment_path(
                    target: @observation.id,
                    type: @observation.class.name
                  )}']")
    end

    def test_not_editable_omits_add_comment_link
      html = render_panel(editable: false)

      assert_no_html(html, "a[data-controller='modal-toggle']")
    end

    # ---- empty / non-empty list rows -------------------------------

    def test_renders_one_comment_item_per_comment
      assert_operator(@comments.length, :>=, 1,
                      "fixture needs >=1 comment for this assertion")

      html = render_panel

      # Each comment is a `.list-group-item.comment` inside
      # `#comments` — count matches the input.
      assert_html(html,
                  "#comments .list-group-item.comment",
                  count: @comments.length)
      # First comment's wrapper carries its dom_id so update
      # broadcasts can target it.
      first = @comments.first
      assert_html(html,
                  "#comments .list-group-item.comment##{dom_id(first)}")
    end

    def test_empty_state_placeholder_when_no_comments
      # The placeholder is always rendered inside `#comments`; the
      # `.list-group-item.none-yet:only-child` CSS rule hides it
      # unless it's the only item. With no comments, it IS the only
      # item.
      html = render_panel(comments: [])

      assert_html(html, "#comments .list-group-item.none-yet",
                  text: :show_comments_no_comments_yet.t)
      assert_html(html, "#comments .list-group-item.comment", count: 0)
    end

    # ---- footer "and N more →" -------------------------------------

    def test_truncated_list_shows_and_more_footer
      and_more = @comments.length - 1

      html = render_panel(editable: true, limit: 1)

      # Inner list shows the truncated set; footer links to the
      # full comments index for this target.
      assert_html(html, "#comments .list-group-item.comment", count: 1)
      assert_html(html, "a[href='#{routes.comments_path(
        target: @observation.id, type: @observation.class.name
      )}']", text: :show_comments_and_more.t(num: and_more).as_displayed)
    end

    def test_no_footer_when_not_editable_even_if_truncated
      html = render_panel(editable: false, limit: 1)

      assert_no_html(html,
                     "a[href*='#{routes.comments_path(
                       target: @observation.id,
                       type: @observation.class.name
                     )}']")
    end

    def test_no_footer_when_within_limit
      # With limit ≥ comment count, `and_more` is ≤ 0 → footer hidden.
      html = render_panel(editable: true, limit: @comments.length + 5)

      assert_no_html(html,
                     "a[href*='#{routes.comments_path(
                       target: @observation.id,
                       type: @observation.class.name
                     )}']")
    end

    private

    def dom_id(record)
      ::ActionView::RecordIdentifier.dom_id(record)
    end

    def render_panel(object: @observation, comments: @comments,
                     user: @user, editable: true, limit: nil)
      render(CommentsForObject.new(
               object: object, comments: comments, user: user,
               editable: editable, limit: limit
             ))
    end
  end
end
