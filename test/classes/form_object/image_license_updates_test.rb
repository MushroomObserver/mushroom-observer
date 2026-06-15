# frozen_string_literal: true

require("test_helper")

class FormObject::ImageLicenseUpdatesTest < ActiveSupport::TestCase
  def test_builds_typed_rows_from_raw_data
    form = FormObject::ImageLicenseUpdates.new(
      data: [
        { "license_count" => 5, "copyright_holder" => "Alice",
          "license_id" => 3,
          "licenses" => [["CC-BY", 1], ["CC-BY-SA", 2]] }
      ]
    )

    assert_equal(1, form.rows.length)
    row = form.rows.first
    assert_instance_of(FormObject::ImageLicenseRow, row)
    assert_equal(5, row.license_count)
    assert_equal("Alice", row.new_holder)
    assert_equal("Alice", row.old_holder)
    assert_equal(3, row.new_id)
    assert_equal(3, row.old_id)
    assert_equal([["CC-BY", 1], ["CC-BY-SA", 2]], row.licenses)
  end

  # `model_name` override is what keeps the wire shape on
  # `params[:updates]` — the controller depends on it.
  def test_model_name_is_updates
    assert_equal("Updates", FormObject::ImageLicenseUpdates.model_name.name)
    assert_equal("updates",
                 FormObject::ImageLicenseUpdates.model_name.singular)
  end

  # `persisted?` is `true` so Superform uses PATCH (matching the
  # license-updater PUT/PATCH route).
  def test_form_is_persisted_for_patch_method
    assert(FormObject::ImageLicenseUpdates.new.persisted?)
  end

  # `method_missing` resolves numeric-string keys to rows so
  # Superform's `namespace(idx.to_s)` finds the right sub-object.
  def test_numeric_string_method_resolves_to_row
    form = FormObject::ImageLicenseUpdates.new(
      data: [{ "copyright_holder" => "Alice", "license_id" => 1,
               "license_count" => 1, "licenses" => [] },
             { "copyright_holder" => "Bob", "license_id" => 2,
               "license_count" => 1, "licenses" => [] }]
    )

    assert_equal(form.rows[0], form.send(:"0"))
    assert_equal(form.rows[1], form.send(:"1"))
    assert_respond_to(form, :"0")
    assert_respond_to(form, :"1")
  end

  # Non-numeric missing methods still raise NoMethodError —
  # `method_missing` falls through to `super` for them.
  def test_non_numeric_missing_method_raises
    form = FormObject::ImageLicenseUpdates.new

    assert_raises(NoMethodError) { form.no_such_method }
    assert_not(form.respond_to?(:no_such_method))
  end
end
