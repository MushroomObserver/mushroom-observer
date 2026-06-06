# frozen_string_literal: true

require("test_helper")

# HTML parity tests: `Components::UserLink` / `Components::ObjectLink`
# / `Components::LocationLink` vs the pre-Phlex helper bodies they
# replaced. Each test inlines a verbatim copy of the original
# `ObjectLinkHelper` method (with `view_context.` prefix on the Rails
# helpers) so the parity check does not rely on the still-extant
# delegate stub in `app/helpers/object_link_helper.rb`.
#
# `assert_dom_equal` is order-insensitive on attributes, which matters
# here: Rails' `link_to` emits class-then-href; Phlex's `a(href:, class:)`
# emits href-then-class. Both are valid HTML; we want behavior parity,
# not byte-level parity on attribute order.
class ObjectLinkHelpersParityTest < ComponentTestCase
  include Rails::Dom::Testing::Assertions::DomAssertions

  # --- UserLink ---------------------------------------------------------

  def test_user_link_parity_with_user_instance
    rolf = users(:rolf)

    assert_dom_equal(legacy_user_link(rolf),
                     render(Components::UserLink.new(user: rolf)))
  end

  def test_user_link_parity_with_integer_id
    assert_dom_equal(legacy_user_link(42),
                     render(Components::UserLink.new(user: 42)))
  end

  def test_user_link_parity_with_name_override
    rolf = users(:rolf)

    assert_dom_equal(legacy_user_link(rolf, "RS"),
                     render(Components::UserLink.new(user: rolf, name: "RS")))
  end

  def test_user_link_parity_with_nil_user
    # Legacy returned a bare string (no anchor); the component does
    # the same. Both render the same `:unknown_user_name.t` text.
    assert_equal(legacy_user_link(nil),
                 render(Components::UserLink.new(user: nil)))
  end

  # --- ObjectLink (a.k.a. link_to_object) -------------------------------

  def test_object_link_parity_with_project
    project = projects(:bolete_project)

    assert_dom_equal(legacy_link_to_object(project),
                     render(Components::ObjectLink.new(object: project)))
  end

  def test_object_link_parity_with_name_override
    project = projects(:bolete_project)

    assert_dom_equal(
      legacy_link_to_object(project, "BP"),
      render(Components::ObjectLink.new(object: project, name: "BP"))
    )
  end

  def test_object_link_parity_with_nil_object
    # Both branches short-circuit to a blank result for nil objects.
    assert_equal(legacy_link_to_object(nil).to_s,
                 render(Components::ObjectLink.new(object: nil)).to_s)
  end

  # --- LocationLink -----------------------------------------------------

  def test_location_link_parity_with_known_location
    burbank = locations(:burbank)

    assert_dom_equal(
      legacy_location_link(burbank.name, burbank),
      render(Components::LocationLink.new(
               where: burbank.name, location: burbank
             ))
    )
  end

  def test_location_link_parity_with_count_and_click
    burbank = locations(:burbank)

    assert_dom_equal(
      legacy_location_link(burbank.name, burbank, 5, true),
      render(Components::LocationLink.new(
               where: burbank.name, location: burbank,
               count: 5, click: true
             ))
    )
  end

  def test_location_link_parity_without_location_goes_to_observations_index
    where = "Some Place, USA"

    assert_dom_equal(legacy_location_link(where, nil),
                     render(Components::LocationLink.new(where: where)))
  end

  def test_location_link_parity_without_location_click_appends_search_suffix
    where = "Somewhere, USA"

    assert_dom_equal(
      legacy_location_link(where, nil, nil, true),
      render(Components::LocationLink.new(where: where, click: true))
    )
  end

  private

  # Inlined copy of the pre-Phlex `ObjectLinkHelper#user_link` body.
  def legacy_user_link(user, name = nil, args = {})
    return :unknown_user_name.t unless user

    if user.is_a?(Integer)
      name ||= "#{:USER.t} ##{user}"
      user_id = user
    else
      name ||= user.unique_text_name
      user_id = user.id
    end

    view_context.link_to(
      name, view_context.user_path(user_id),
      args.merge(class: [
        "user_link_#{user_id}", args[:class]
      ].compact.join(" "))
    )
  end

  # Inlined copy of the pre-Phlex `ObjectLinkHelper#link_to_object` body.
  def legacy_link_to_object(object, name = nil)
    return nil unless object

    view_context.link_to(
      name || object.title.t, object.show_link_args,
      class: "#{object.type_tag}_link_#{object.id}"
    )
  end

  # Inlined copy of the pre-Phlex `ObjectLinkHelper#location_link` body
  # (plus its `where_string` collaborator). Original positional
  # `click = false` kept as a positional default in this verbatim copy
  # — the tests pass it positionally so the rubocop hint about
  # keyword args doesn't apply.
  def legacy_location_link(where, location, count = nil, click = false) # rubocop:disable Style/OptionalBooleanParameter
    if location
      location = Location.find(location) unless location.is_a?(AbstractModel)
      str = legacy_where_string(location.name, count)
      str += " [#{:click_for_map.t}]" if click
      view_context.link_to(
        str, view_context.location_path(id: location.id),
        class: "show_location_link show_location_link_#{location.id}"
      )
    else
      str = legacy_where_string(where, count)
      str += " [#{:SEARCH.t}]" if click
      view_context.link_to(
        str, view_context.observations_path(where: where),
        class: "index_observations_at_where_link"
      )
    end
  end

  def legacy_where_string(where, count = nil)
    postal = view_context.tag.span(where, class: "location-postal")
    scientific = view_context.tag.span(Location.reverse_name(where),
                                       class: "location-scientific")
    add_count = count ? " (#{count})" : ""
    view_context.tag.span do
      [postal, scientific, add_count].join.html_safe # rubocop:disable Rails/OutputSafety
    end
  end
end
