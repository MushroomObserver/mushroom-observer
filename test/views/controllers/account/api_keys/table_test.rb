# frozen_string_literal: true

require("test_helper")

# Tests for Views::Controllers::Account::APIKeys::Table — the
# Phlex view file that renders the account/api_keys index table
# plus the "+ Add Key" accordion below.
module Views
  module Controllers
    module Account
      module APIKeys
        class TableTest < ComponentTestCase
          def setup
            super
            @user = users(:rolf)
          end

          def test_renders_keys_table_with_all_columns_and_sorted_rows
            html = render_table

            assert_html(html, "table#account_api_keys_table.table-striped")
            # Column headers (verified, created, last used, num uses,
            # key, notes, remove). 7 columns total.
            assert_html(html, "thead th", count: 7)
            # One row per key (rolf has two fixtures: an active key
            # and an unverified key — see api_keys.yml).
            assert_html(html,
                        "tbody tr",
                        count: @user.api_keys.count)
          end

          def test_renders_activate_button_for_unverified_key
            key = api_keys(:rolfs_mo_app_api_key)
            key.update!(verified: nil)
            html = render_table

            assert_html(html,
                        "button#activate_api_key_#{key.id}",
                        text: :ACTIVATE.l)
          end

          def test_renders_verified_indicator_for_verified_key
            key = api_keys(:rolfs_api_key)
            html = render_table

            assert_html(
              html,
              "#api_key_#{key.id} input[type='checkbox'][disabled]"
            )
          end

          def test_renders_notes_accordion_per_row
            key = api_keys(:rolfs_api_key)
            html = render_table

            # View pane (read-only notes + edit trigger).
            assert_html(html, "#view_notes_#{key.id}_container .current_notes")
            assert_html(html,
                        "button[data-role='edit_api_key']" \
                        "[data-target='#edit_notes_#{key.id}_container']")
            # Edit pane (inline-edit APIKeyForm with Save button).
            assert_html(html,
                        "#edit_api_key_#{key.id}_form " \
                        "input##{"api_key_#{key.id}_notes"}")
            assert_html(html,
                        "#edit_api_key_#{key.id}_form " \
                        "input[type='submit'][value='#{:SAVE.l}']")
          end

          def test_renders_remove_button_per_row
            key = api_keys(:rolfs_api_key)
            html = render_table

            assert_html(html,
                        "form[action='/account/api_keys/#{key.id}']" \
                        "[method='post']")
            assert_html(html,
                        "input[type='hidden'][name='_method'][value='delete']")
          end

          def test_renders_new_form_accordion_below_table
            html = render_table

            # "+ Add Key" link triggers expansion to the inline form.
            assert_html(html, "#new_key_row #new_key_button_container " \
                              "a#new_key_button[href='/account/api_keys/new']")
            # Inline create form lives in the hidden pane.
            assert_html(html, "#new_key_form_container #new_api_key_form")
            assert_html(html,
                        "#new_api_key_form " \
                        "input[type='submit'][value='#{:CREATE.l}']")
          end

          def test_renders_empty_table_when_user_has_no_keys
            user = users(:zero_user)
            html = render_table(user: user)

            assert_html(html, "table#account_api_keys_table")
            assert_html(html, "tbody tr", count: 0)
            # New-form panel still shows so the user can create their first.
            assert_html(html, "#new_key_button")
          end

          private

          def render_table(user: @user)
            render(Views::Controllers::Account::APIKeys::Table.new(
                     user: user
                   ))
          end
        end
      end
    end
  end
end
