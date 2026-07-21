# frozen_string_literal: true

require("test_helper")

class VisualGroupsControllerTest < FunctionalTestCase
  setup do
    @visual_group = visual_groups(:visual_group_two)
    @visual_model = @visual_group.visual_model
  end

  def test_should_get_index
    login
    get(:index, params: { visual_model_id: @visual_model.id })
    assert_response(:success)
  end

  def test_should_get_new
    login
    get(:new, params: { visual_model_id: @visual_model.id })
    assert_response(:success)
  end

  def test_should_create_visual_group
    login
    assert_difference("VisualGroup.count") do
      post(:create, params: {
             visual_model_id: @visual_model.id,
             visual_group: {
               name: @visual_group.name,
               approved: @visual_group.approved
             }
           })
    end
    assert_redirected_to(visual_model_visual_groups_url(
                           @visual_model, VisualGroup.last
                         ))
  end

  def test_should_not_create_visual_group
    login
    assert_no_difference("VisualGroup.count") do
      post(:create, params: {
             visual_model_id: @visual_model.id,
             visual_group: {
               name: "",
               approved: @visual_group.approved
             }
           })
    end
    assert_redirected_to(new_visual_model_visual_group_url(@visual_model))
  end

  def test_should_not_create_visual_group_due_to_tab
    login
    assert_no_difference("VisualGroup.count") do
      post(:create, params: {
             visual_model_id: @visual_model.id,
             visual_group: {
               name: "Name\twith\ttab",
               approved: @visual_group.approved
             }
           })
    end
    assert_redirected_to(new_visual_model_visual_group_url(@visual_model))
  end

  def test_should_show_visual_group
    login
    get(:show, params: {
          id: @visual_group.id,
          visual_model_id: @visual_model.id
        })
    assert_response(:success)
  end

  def test_should_show_visual_group_with_filter
    login
    get(:show, params: {
          id: @visual_group.id,
          filter: "Agaricus",
          visual_model_id: @visual_model.id
        })
    assert_response(:success)
  end

  def test_should_get_edit
    login
    get(:edit, params: { id: @visual_group.id })
    assert_response(:success)
    assert_match(image_path(observations(:peltigera_mary_obs).thumb_image.id),
                 response.body)
  end

  def test_should_get_edit_page_with_excluded_images
    login
    get(:edit, params: { id: @visual_group.id, status: "excluded" })
    assert_response(:success)
  end

  # The filter form on the edit page combines status (button-group)
  # and filter text in one form. Verify the form's rendered shape
  # AND that the controller correctly reads both params together.

  def test_edit_filter_form_renders_combined_form
    login
    get(:edit, params: { id: @visual_group.id })

    # One filter form on the page, with form-inline shell.
    assert_select("form#visual_group_filters_form.form-inline", count: 1) do
      # Hidden status field carries the current status when the user
      # submits via the text-input's submit button.
      assert_select(
        "input[type=hidden][name=status][value=needs_review]", count: 1
      )
      # Three status submit buttons; the current one ("needs_review")
      # is a non-clickable `<span>` (aria-disabled) so the user can't
      # redundantly re-submit the active status.
      assert_select(
        "span[aria-disabled='true']",
        text: :visual_group_needs_review.t
      )
      assert_select(
        "button[type=submit][name=status][value=included]",
        text: :visual_group_included.t
      )
      assert_select(
        "button[type=submit][name=status][value=excluded]",
        text: :visual_group_excluded.t
      )
      # Text filter input + its dedicated submit button.
      assert_select("input[type=text][name=filter]#filter")
      assert_select(
        "button[type=submit]",
        text: :edit_visual_group_update_filter.t
      )
    end
    # Reload button only on needs_review (which is the default).
    assert_select("button[onclick]", text: :reload.ti)
  end

  def test_edit_filter_form_reload_link_hidden_on_included
    login
    get(:edit, params: { id: @visual_group.id, status: "included" })

    # Active button is the "Included" span (aria-disabled) now.
    assert_select(
      "span[aria-disabled='true']", text: :visual_group_included.t
    )
    # Reload button only shows on needs_review.
    assert_select("button[onclick]", count: 0)
  end

  # Submitting the form with both `status` and `filter` set: the
  # controller should pick up both. The button-set's `status` value
  # wins over the hidden `status` field via Rails' last-value-wins
  # param parsing — the hidden appears first in DOM, status buttons
  # appear later, so the button's value is the LAST `status` in the
  # query string.
  def test_edit_filter_form_submission_carries_status_and_filter
    login
    # Simulate what the form sends when user clicks "Included"
    # with text in the filter input. Rack's query parser keeps
    # the LAST value when the same key appears twice, so order
    # matters: hidden first, button second.
    get(:edit, params: { id: @visual_group.id,
                         status: "included",
                         filter: "Trametes" })

    assert_response(:success)
    assert_equal("included", assigns(:status))
    assert_equal("Trametes", assigns(:filter))
  end

  def test_edit_filter_form_submission_with_only_filter_preserves_status
    login
    # User typed in the text input and clicked the "Update Filter"
    # submit button. The browser sends only the hidden status value
    # (since the user didn't click a status button), preserving
    # whatever status they were on.
    get(:edit, params: { id: @visual_group.id,
                         status: "excluded",
                         filter: "Cantharellus" })

    assert_response(:success)
    assert_equal("excluded", assigns(:status))
    assert_equal("Cantharellus", assigns(:filter))
  end

  def test_should_update_visual_group
    login
    patch(:update, params: {
            id: @visual_group.id,
            visual_group: {
              name: @visual_group.name,
              approved: @visual_group.approved
            }
          })
    assert_redirected_to(visual_model_visual_groups_url(@visual_model,
                                                        @visual_group))
  end

  def test_should_not_update_visual_group
    login
    patch(:update, params: {
            id: @visual_group.id,
            visual_group: {
              name: "",
              approved: @visual_group.approved
            }
          })
    assert_redirected_to(edit_visual_group_url(@visual_group))
  end

  def test_should_destroy_visual_group
    login
    assert_difference("VisualGroup.count", -1) do
      delete(:destroy, params: { id: @visual_group.id })
    end
    assert_redirected_to(visual_model_visual_groups_url(@visual_model))
  end
end
