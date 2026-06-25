# frozen_string_literal: true

require "test_helper"

module Views::Controllers::Account::APIKeys
  class FormTest < ComponentTestCase
    def setup
      super
      @api_key = APIKey.new
    end

    def test_renders_standalone_layout_without_cancel_button
      html = render_form_without_cancel

      assert_html(html, ".form-group")
      assert_html(
        html, "label", text: :account_api_keys_notes_label.l
      )
      assert_html(html, "#api_key_notes")
      assert_html(
        html,
        "button[type='submit']", text: :account_api_keys_create_button.l
      )
    end

    def test_renders_table_layout_with_cancel_button
      html = render_form_with_cancel

      assert_html(html, ".input-group")
      assert_includes(html, :CANCEL.l)
      assert_html(html, ".input-group-btn")
      assert_html(html, "#api_key_notes")
      assert_html(html, "button[data-toggle='collapse']")
    end

    def test_cancel_button_has_correct_data_attributes
      html = render_form_with_cancel

      assert_html(html, "button[data-target='#test_target']")
      assert_html(html, "button[data-parent='#test_parent']")
      assert_html(html, "button[aria-controls='test_target']")
    end

    def test_cancel_button_not_rendered_when_nil
      html = render_form_without_cancel

      assert_not_includes(html, "input-group")
    end

    def test_table_layout_has_one_label_outside_input_group
      html = render_form_with_cancel

      # Should have exactly one label
      assert_html(html, "label", count: 1)

      # Label should have correct for attribute and be outside .input-group
      assert_html(html, "label[for='api_key_notes']")
      assert_no_html(html, ".input-group label[for='api_key_notes']")

      # Input should not be wrapped in form-group inside input-group
      assert_no_html(html, ".input-group .form-group")
    end

    # Edit-layout tests — the persisted-model branch renders a
    # metadata table (created, last_used, num_uses, API key value)
    # plus the notes input plus Update / Cancel submit buttons. Used
    # by `account/api_keys/edit.rb` (the no-JS fallback view).

    def test_edit_layout_renders_metadata_table_for_persisted_key
      key = api_keys(:rolfs_api_key)
      html = render_edit_form(key)

      assert_html(html, "table")
      assert_includes(html, :CREATED.l)
      assert_includes(html, :account_api_keys_last_used_column_label.l)
      assert_includes(html, :account_api_keys_num_uses_column_label.l)
      assert_includes(html, :API_KEY.l)
      # The API key's raw key value is shown so the user can copy it.
      assert_includes(html, key.key)
    end

    def test_edit_layout_renders_update_submit_and_cancel_link
      key = api_keys(:rolfs_api_key)
      html = render_edit_form(key)

      # Update is a real submit button on the form.
      assert_html(html, "button[type='submit']", text: :UPDATE.l)
      # Cancel is a navigation link back to the index — NOT a submit.
      # (Pre-Phlex was a submit, which paradoxically meant clicking
      # Cancel ran an update via the controller's update action.)
      assert_html(html, "a[href='/account/api_keys']", text: :CANCEL.l)
      assert_no_html(html,
                     "button[type='submit']", text: :CANCEL.l)
    end

    def test_edit_layout_renders_notes_input_under_api_key_scope
      key = api_keys(:rolfs_api_key)
      html = render_edit_form(key)

      # Critical: the input must post under `api_key[notes]` so the
      # controller's `params[:api_key].permit(:notes)` picks it up.
      # Superform derives the scope from the model class (`APIKey` →
      # `:api_key`).
      assert_html(html, "input[name='api_key[notes]']")
    end

    def test_persisted_model_uses_patch_method
      key = api_keys(:rolfs_api_key)
      html = render_edit_form(key)

      assert_html(html,
                  "input[type='hidden'][name='_method'][value='patch']")
    end

    # Inline-edit-layout tests — the persisted + cancel_target branch
    # renders the per-row notes editor that swaps into the accordion's
    # edit pane on the index page.

    def test_inline_edit_layout_renders_input_group_with_save_and_cancel
      key = api_keys(:rolfs_api_key)
      html = render_inline_edit_form(key)

      assert_html(html, ".input-group .input-group-btn")
      # Cancel button (button, not submit) with the per-row collapse
      # data attributes to swap back to the view pane.
      assert_html(html,
                  ".input-group button[type='button']" \
                  "[data-toggle='collapse']" \
                  "[data-target='#view_notes_#{key.id}_container']" \
                  "[data-parent='#notes_#{key.id}']")
      # Save submit (not Update — that's the standalone-edit layout).
      assert_html(html,
                  "button[type='submit']", text: :SAVE.l)
      assert_no_html(html,
                     "button[type='submit']", text: :UPDATE.l)
    end

    def test_inline_edit_notes_input_has_per_key_id_to_avoid_collisions
      key = api_keys(:rolfs_api_key)
      html = render_inline_edit_form(key)

      # Per-key id so multiple inline-edit forms on the index page
      # don't share #api_key_notes (Superform's default class-based id).
      assert_html(html,
                  "input[name='api_key[notes]']" \
                  "[id='api_key_#{key.id}_notes']")
    end

    def test_inline_edit_layout_omits_standalone_edit_metadata_table
      key = api_keys(:rolfs_api_key)
      html = render_inline_edit_form(key)

      # The standalone-edit layout renders a metadata table (created /
      # last_used / num_uses / API key); inline edit must not.
      assert_no_html(html, "table")
    end

    private

    def render_form_without_cancel
      form = Form.new(
        @api_key,
        action: "/test_api_keys_path",
        id: "new_api_key_form"
      )
      render(form)
    end

    def render_form_with_cancel
      form = Form.new(
        @api_key,
        action: "/test_api_keys_path",
        id: "new_api_key_form",
        cancel_target: "test_target",
        cancel_parent: "test_parent"
      )
      render(form)
    end

    def render_edit_form(key)
      form = Form.new(
        key,
        action: "/account/api_keys/#{key.id}",
        id: "account_edit_api_key_form"
      )
      render(form)
    end

    def render_inline_edit_form(key)
      form = Form.new(
        key,
        action: "/account/api_keys/#{key.id}",
        id: "edit_api_key_#{key.id}_form",
        cancel_target: "view_notes_#{key.id}_container",
        cancel_parent: "notes_#{key.id}"
      )
      render(form)
    end
  end
end
