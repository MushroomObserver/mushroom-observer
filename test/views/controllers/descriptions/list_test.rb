# frozen_string_literal: true

require("test_helper")

# Component-level smoke tests for `Views::Controllers::Descriptions::List`. The
# component is a thin wrapper around `DescriptionsHelper#list_descriptions`
# (registered as a value-helper); these tests cover the wrapper's two
# observable behaviors: each description gets wrapped in its own `<div>`,
# and an object with no descriptions renders nothing.
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

  def test_each_div_contains_a_description_link
    name = names_with_descriptions

    html = render(Views::Controllers::Descriptions::List.new(
                    user: @user, object: name, type: :name
                  ))

    name.descriptions.each do |desc|
      assert_html(html, "a.description_link_#{desc.id}")
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
