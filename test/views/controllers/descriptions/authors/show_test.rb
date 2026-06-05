# frozen_string_literal: true

require "test_helper"

class Views::Controllers::Descriptions::Authors::ShowTest <
  ComponentTestCase
  def test_renders_authors_block_with_destroy_buttons
    desc = name_descriptions(:peltigera_user_desc)
    rolf = users(:rolf)
    desc.add_author(rolf)
    desc.reload

    html = render(Views::Controllers::Descriptions::Authors::Show.new(
                    object: desc, authors: desc.authors
                  ))

    # Each author row has a remove-author destroy button posting to
    # description_authors_path with the user id in `remove=…`.
    assert_html(html,
                "form[action*='/descriptions/authors?']" \
                "[action*='remove=#{rolf.id}']")
  end

  def test_renders_add_author_form_for_other_users_pool
    desc = location_descriptions(:albion_desc)

    html = render(Views::Controllers::Descriptions::Authors::Show.new(
                    object: desc, authors: []
                  ))

    # User autocompleter input — the field name is namespaced under
    # the `AddAuthor` FormObject (`add_author[user]`). The controller's
    # `create` action handles both `params[:add]` (legacy) and
    # `params.dig(:add_author, :user)` (new).
    assert_html(html, "input[name='add_author[user]']")
    assert_html(html, "form[action*='/descriptions/authors']" \
                      "[action*='id=#{desc.id}']")
    # Stimulus controller for the user autocompleter.
    assert_html(
      html,
      "div.autocompleter[data-controller~='autocompleter--user']"
    )
  end

  def test_renders_review_note_only_for_name_descriptions
    name_desc = name_descriptions(:peltigera_user_desc)
    location_desc = location_descriptions(:albion_desc)

    name_html = render(Views::Controllers::Descriptions::Authors::Show.new(
                         object: name_desc, authors: []
                       ))
    loc_html = render(Views::Controllers::Descriptions::Authors::Show.new(
                        object: location_desc, authors: []
                      ))

    note_text = :review_authors_note.t.strip_html
    sanitize = ActionView::Base.full_sanitizer.method(:sanitize)
    assert_includes(sanitize.call(name_html), note_text)
    assert_not_includes(sanitize.call(loc_html), note_text)
  end
end
