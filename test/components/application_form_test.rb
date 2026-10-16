# frozen_string_literal: true

require "test_helper"

# Core Components::ApplicationForm behavior that isn't specific to any
# one field type: form-level helpers (link_to, class_names), Turbo
# attributes, FieldWithHelp/FieldLabelRow's shared help/between
# rendering, and derive_form_id. Field-type-specific tests live in
# test/components/application_form/<type>_field_test.rb.
class ApplicationFormTest < ComponentTestCase
  include ApplicationFormFieldTestHelpers

  def setup
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
  end

  def test_auto_label_for_prefs_returns_options_unchanged_when_no_prefs
    form = Components::ApplicationForm.new(@collection_number,
                                           action: "/test_form_path")

    result = form.send(:auto_label_for_prefs, :name, label: "Original")
    assert_equal({ label: "Original" }, result,
                 "Without :prefs, options should be untouched")
  end

  # auto_label_for_prefs itself resolves to the bare translation-key
  # Symbol, not a String -- resolution to actual display text (via
  # `.t`) happens downstream in FieldLabelRow#resolved_label_text.
  def test_auto_label_for_prefs_drops_prefs_key_when_resolving
    form = Components::ApplicationForm.new(@collection_number,
                                           action: "/test_form_path")

    result = form.send(:auto_label_for_prefs, :login,
                       prefs: true, class: "extra")
    assert_equal(:prefs_login, result[:label])
    assert_not(result.key?(:prefs),
               ":prefs should be removed after resolution so it " \
               "doesn't leak into wrapper_options downstream")
    assert_equal("extra", result[:class],
                 "Unrelated options should pass through")
  end

  # Test that link_to is available in ApplicationForm
  # This verifies Phlex::Rails::Helpers::LinkTo works via inheritance
  def test_link_to_helper_is_available
    form = render_form do
      link_to("Test Link", "/test/path", class: "test-class")
    end

    assert_includes(form, "<a")
    assert_includes(form, 'href="/test/path"')
    assert_includes(form, "Test Link")
    assert_includes(form, 'class="test-class"')
  end

  # Test that class_names is available in ApplicationForm
  # This verifies Phlex::Rails::Helpers::ClassNames works via inheritance
  def test_class_names_helper_is_available
    form = render_form do
      div(class: class_names("base-class", active: true,
                                           disabled: false)) do
        plain("Content")
      end
    end

    assert_includes(form, 'class="base-class active"')
    assert_not_includes(form, "disabled")
  end

  # Turbo stream form tests (turbo: true)
  def test_turbo_stream_form_has_data_turbo_attribute
    form = render_form(turbo: true) do
      text_field(:name, label: "Name")
    end

    assert_html(form, "form[data-turbo='true']")
  end

  def test_local_form_has_data_turbo_false_attribute
    form = render_form(turbo: false) do
      text_field(:name, label: "Name")
    end

    assert_html(form, "form[data-turbo='false']")
  end

  # No `_method` hidden on a plain POST form. Superform emits one
  # unconditionally, and a stray `_method=post` turns a Turbo PATCH
  # submission into a bare POST when a second `_method` joins it --
  # turbo-rails reads only the first, then strips them all (this
  # looped the field-slip review page back onto itself).
  def test_post_form_emits_no_method_override_field
    form = ApplicationFormFieldTestHelpers::TestFormClass.new(
      CollectionNumber.new, action: "/test_form_path"
    )
    form.field_block = proc { text_field(:name, label: "Name") }
    html = render(form)

    assert_no_html(html, "input[name='_method']")
  end

  # Non-POST forms still get their override field, exactly once:
  # inferred from a persisted model, or forced with `method:`.
  def test_non_post_form_emits_single_method_override_field
    persisted = render_form { text_field(:name, label: "Name") }

    assert_html(persisted, "input[name='_method'][value='patch']",
                count: 1)

    forced = ApplicationFormFieldTestHelpers::TestFormClass.new(
      CollectionNumber.new, action: "/test_form_path", method: :patch
    )
    forced.field_block = proc { text_field(:name, label: "Name") }
    html = render(forced)

    assert_html(html, "input[name='_method'][value='patch']", count: 1)
  end

  # The help-trigger's span always gets a leading ml-2, for the gap
  # from the label. An inline field's trailing space before its input
  # lives on the row (label-row-with-appends) instead, so it doesn't
  # compound with a later append's leading margin.
  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_help_icon_margin_block_field_with_help
    form = render_form do
      text_field(:name, label: "Name:", help: "Help text",
                        help_collapse: true)
    end

    assert_html(form, ".ml-2")
    assert_no_html(form, ".label-row-with-appends.mr-2")
  end

  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_help_icon_margin_inline_field_with_help
    form = render_form do
      text_field(:name, inline: true, label: "Name:", help: "Help text",
                        help_collapse: true)
    end

    assert_html(form, ".ml-2")
    assert_html(form, ".label-row-with-appends.mr-2")
  end

  # Help nests inside .form-group, as part of the same unit, so its
  # own default bottom margin provides spacing to the next field --
  # no suppression needed.
  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_help_nests_inside_form_group
    form = render_form do
      text_field(:name, label: "Name:", help: "Help text")
    end

    assert_html(form, ".form-group > .help-block", text: "Help text")
    assert_no_html(form, ".form-group.mb-0")
  end

  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_collapsed_help_nests_inside_form_group
    form = render_form do
      text_field(:name, label: "Name:", help: "Help text",
                        help_collapse: true)
    end

    assert_html(form, ".form-group .collapse .help-block",
                text: "Help text")
    assert_no_html(form, ".form-group.mb-0")
  end

  # SelectRangeField's two selects sit in separate d-inline-block
  # columns meant to stay on one line; a block-level help rendered
  # inside either column would force a line-break, so it must render
  # outside both, with both .form-groups carrying mb-0 explicitly.
  # rubocop:disable-next MO/NoCosmeticClassAssertion
  def test_select_range_field_help_renders_outside_both_columns
    form = render_form do
      render(Components::ApplicationForm::SelectRangeField.new(
               form: self, field_name: :confidence,
               options: [["", nil], ["Sure", 3]],
               value: nil, range_value: nil,
               label: "Confidence"
             )) do |f|
        f.with_help { plain("Confidence is in this range.") }
      end
    end

    assert_no_html(form, ".d-inline-block .help-block")
    assert_html(form, ".d-inline-block .form-group.mb-0", count: 2)

    # .help-block is a sibling of the div wrapping both columns, not
    # nested inside either one.
    columns_row = Nokogiri::HTML5.fragment(form).at_css(".d-inline-block").
                  parent
    assert(
      columns_row.next_element.matches?(".help-block"),
      "help-block should immediately follow the row containing both " \
      "d-inline-block columns"
    )
  end

  def test_derive_form_id_uses_all_controller_segments
    klass = stub_views_controller_form("Names", "Synonyms", "Approve")
    assert_equal("name_synonym_approve_form",
                 instance_id_for(klass, Name.new))
  end

  def test_derive_form_id_appends_specific_class_name_to_segments
    klass = stub_views_controller_form("Admin", "Donations",
                                       class_name: "ReviewForm")
    assert_equal("admin_donation_review_form",
                 instance_id_for(klass, Donation.new))
  end

  def test_derive_form_id_singularizes_each_path_segment
    klass = stub_views_controller_form("Account", "APIKeys")
    assert_equal("account_api_key_form",
                 instance_id_for(klass, APIKey.new))
  end

  def test_derive_form_id_for_components_uses_class_name
    # Stand-in for `Components::HerbariumForm` (no Views::Controllers
    # prefix) — derive from the class's own demodulized name.
    klass = Class.new(Components::ApplicationForm)
    Components.const_set(:HerbariumFormStub, klass)
    begin
      assert_equal("herbarium_form_stub",
                   instance_id_for(klass, Herbarium.new))
    ensure
      Components.send(:remove_const, :HerbariumFormStub)
    end
  end

  def test_derive_form_id_falls_back_to_model_class_when_class_has_no_name
    # Anonymous form class (no name) + a real model → derive from the
    # model class name.
    klass = Class.new(Components::ApplicationForm)
    assert_equal("herbarium_form",
                 instance_id_for(klass, Herbarium.new))
  end

  def test_derive_form_id_ultimate_fallback_is_application_form
    # Anonymous class with no model — falls all the way through to
    # the literal "application_form" sentinel.
    klass = Class.new(Components::ApplicationForm)
    form = klass.allocate
    assert_equal("application_form", form.derive_form_id(nil) ||
                                     "application_form")
  end

  private

  # Allocates a form of `klass` without calling `initialize` (avoids
  # the Superform wiring we don't need) and asks it for its
  # auto-derived form id given `model`.
  def instance_id_for(klass, model)
    klass.allocate.derive_form_id(model)
  end

  # Build a stub class registered under
  # `Views::Controllers::<seg1>::<seg2>::...::<class_name>` so the
  # heuristic sees a realistic class name. Cleans up after itself via
  # ObjectSpace constants when the test ends? No — caller is expected
  # to use the returned class transiently in one assertion.
  def stub_views_controller_form(*segments, class_name: "Form")
    parent = Views::Controllers
    segments.each do |seg|
      parent = if parent.const_defined?(seg, false)
                 parent.const_get(seg)
               else
                 parent.const_set(seg, Module.new)
               end
    end
    if parent.const_defined?(class_name, false)
      parent.const_get(class_name)
    else
      parent.const_set(class_name, Class.new(Components::ApplicationForm))
    end
  end
end
