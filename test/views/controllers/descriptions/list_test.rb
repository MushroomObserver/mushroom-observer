# frozen_string_literal: true

require("test_helper")

# Component-level smoke tests for `Views::Controllers::Descriptions::List`.
# Covers: each visible description gets its own `<div>`, readable ones
# render as `<a class="description_link_#{id}">`, non-readable ones
# render as plain text (no `<a>`), and an object with no descriptions
# renders nothing (or the `empty_text` fallback).
class Views::Controllers::Descriptions::ListTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
  end

  def test_renders_one_div_per_description
    name = names_with_descriptions
    description_count = list_descriptions_for(name)

    html = render(Views::Controllers::Descriptions::List.new(
                    user: @user, object: name, type: :name
                  ))
    doc = Nokogiri::HTML.fragment(html)

    assert_operator(description_count, :>, 0,
                    "Need a name fixture with descriptions for this test")
    assert_equal(description_count,
                 doc.children.count { |c| c.name == "div" })
  end

  def test_readable_descriptions_render_as_links
    name = names_with_descriptions

    html = render(Views::Controllers::Descriptions::List.new(
                    user: @user, object: name, type: :name
                  ))

    readable, unreadable = name.descriptions.partition do |desc|
      desc.is_reader?(@user)
    end
    assert(readable.any?, "Need at least one description rolf can read")

    readable.each do |desc|
      assert_html(html, "a.description_link_#{desc.id}")
    end
    unreadable.each do |desc|
      assert_no_html(html, "a.description_link_#{desc.id}")
    end
  end

  def test_renders_nothing_for_object_with_no_descriptions
    name = Name.left_joins(:descriptions).
           where(name_descriptions: { id: nil }).first
    assert_empty(name.descriptions)

    html = render(Views::Controllers::Descriptions::List.new(
                    user: @user, object: name, type: :name
                  ))

    assert_equal("", html.strip)
  end

  def test_emits_empty_text_when_no_descriptions
    name = Name.left_joins(:descriptions).
           where(name_descriptions: { id: nil }).first
    html = render(Views::Controllers::Descriptions::List.new(
                    user: @user, object: name, type: :name,
                    empty_text: "No descriptions here."
                  ))

    assert_includes(html, "No descriptions here.")
  end

  private

  def names_with_descriptions
    Name.joins(:descriptions).group("names.id").
      having("count(name_descriptions.id) > 1").first ||
      flunk("Need a Name fixture with multiple NameDescriptions")
  end

  # Drive the helper through the view-context binding (the test class
  # itself doesn't have direct access to helper methods).
  def list_descriptions_for(name)
    @controller.view_context.list_descriptions(
      user: @user, object: name, type: :name
    )&.size || 0
  end
end
