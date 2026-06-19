# frozen_string_literal: true

require("test_helper")

class ListGroupTest < ComponentTestCase
  def test_renders_plain_list_group_with_items
    html = render(Components::ListGroup::Base.new) do |list|
      list.item { "one" }
      list.item { "two" }
    end

    # Default `<div>` container with `list-group`; each item is a
    # `<div class="list-group-item">` in declaration order.
    assert_html(html, "div.list-group")
    assert_html(html, "div.list-group > div.list-group-item", count: 2)
  end

  def test_flush_adds_list_group_flush_class
    html = render(Components::ListGroup::Base.new(flush: true)) do |list|
      list.item { "x" }
    end

    # Used when the list nests inside a `Panel` body so the panel's
    # own border owns the outer edge.
    assert_html(html, "div.list-group.list-group-flush")
  end

  def test_ul_element_switches_items_to_li
    html = render(Components::ListGroup::Base.new(element: :ul)) do |list|
      list.item { "one" }
      list.item { "two" }
    end

    # `<ul>` container → `<li>` items (semantic shape for lists of
    # like-kind records).
    assert_html(html, "ul.list-group")
    assert_html(html, "ul.list-group > li.list-group-item", count: 2)
  end

  def test_container_id_and_class_extras_flow_through
    html = render(Components::ListGroup::Base.new(
                    id: "namings_table_rows",
                    flush: true, class: "namings"
                  )) do |list|
      list.item { "x" }
    end

    # `id` and extra class on the container — pinned because the id
    # is the Turbo Stream target hook for the namings sub-panel.
    assert_html(html, "div#namings_table_rows.list-group.namings")
  end

  def test_container_data_attributes_pass_through
    html = render(Components::ListGroup::Base.new(
                    attributes: { data: { controller: "section-update" } }
                  )) do |list|
      list.item { "x" }
    end

    # Stimulus wiring on the container — namings uses `section-update`
    # to swap rows in via Action Cable.
    assert_html(html, "div.list-group[data-controller='section-update']")
  end

  def test_per_item_id_and_class_extras_flow_through
    html = render(Components::ListGroup::Base.new) do |list|
      list.item(id: "naming_42", class: "consensus-row") { "x" }
    end

    # Per-row id + extras are how the namings rows get
    # `id="observation_naming_<id>"` for selector / Turbo targeting.
    assert_html(html, "div.list-group-item#naming_42.consensus-row")
  end

  def test_per_item_arbitrary_attributes_pass_through
    html = render(Components::ListGroup::Base.new) do |list|
      list.item(data: { foo: "bar" }) { "x" }
    end

    assert_html(html, "div.list-group-item[data-foo='bar']")
  end

  def test_empty_slot_always_rendered_as_trailing_none_yet_item
    # The empty placeholder is always emitted as a trailing
    # `.list-group-item.none-yet`. The `.list-group-item.none-yet`
    # CSS rule in `_utilities.scss` hides it unless it's the only
    # `.list-group-item` child — so it shows iff no real rows
    # exist. Works seamlessly with Turbo Stream `append` / `remove`
    # broadcasts that only touch real items.
    html = render(Components::ListGroup::Base.new) do |list|
      list.item { "real row" }
      list.empty { "nothing yet" }
    end

    assert_html(html, "div.list-group > div.list-group-item",
                count: 2)
    assert_html(html, "div.list-group-item.none-yet",
                text: "nothing yet")
    assert_html(html, "div.list-group-item:not(.none-yet)",
                text: "real row")
  end

  def test_empty_slot_renders_even_without_real_items
    html = render(Components::ListGroup::Base.new) do |list|
      list.empty { "nothing yet" }
    end

    # No real items → the placeholder is the only child → CSS
    # `:only-child` rule lets it show on the page.
    assert_html(html, "div.list-group > div.list-group-item.none-yet",
                text: "nothing yet")
  end

  def test_renders_only_container_when_no_items_no_empty
    # Empty list with neither items nor placeholder: just the outer
    # container. Helpful for streamed-in content where items arrive
    # via Turbo later.
    html = render(Components::ListGroup::Base.new) do |list|
      # intentionally empty — no list.item / list.empty calls
      _ = list
    end

    assert_html(html, "div.list-group")
    assert_no_html(html, "div.list-group > div.list-group-item")
  end

  def test_item_blocks_capture_iteration_local
    # Each block must close over its OWN value of `n` from the loop,
    # not a single shared one — proves the deferred-render pattern
    # captures iteration-local bindings correctly.
    html = render(Components::ListGroup::Base.new) do |list|
      (1..3).each do |n|
        list.item { "row #{n}" }
      end
    end

    assert_html(html, "div.list-group-item", count: 3)
    assert_includes(html, "row 1")
    assert_includes(html, "row 2")
    assert_includes(html, "row 3")
  end
end
