# frozen_string_literal: true

require("test_helper")

class FieldSlip::TemplateTest < UnitTestCase
  def test_for_returns_the_named_template
    assert_instance_of(FieldSlip::Template::Mo, FieldSlip::Template.for(:mo))
    assert_instance_of(FieldSlip::Template::Dbg,
                       FieldSlip::Template.for("dbg"))
    assert_instance_of(FieldSlip::Template::Nama,
                       FieldSlip::Template.for(:nama))
  end

  def test_for_rejects_an_unknown_template
    assert_raises(ArgumentError) { FieldSlip::Template.for(:nemf) }
  end

  def test_default_is_the_mo_slip
    assert_instance_of(FieldSlip::Template::Mo, FieldSlip::Template.default)
  end

  def test_keys_match_the_registry
    FieldSlip::Template::REGISTRY.each_key do |key|
      assert_equal(key, FieldSlip::Template.for(key).key)
    end
  end

  # Selection is by the project's field_slip_prefix, so it holds in
  # every environment regardless of ids.
  def test_for_project_uses_the_prefix
    project = projects(:bolete_project)
    project.field_slip_prefix = "2026-CMS"

    assert_instance_of(FieldSlip::Template::Dbg,
                       FieldSlip::Template.for_project(project))

    project.field_slip_prefix = "2026-NAMA"

    assert_instance_of(FieldSlip::Template::Nama,
                       FieldSlip::Template.for_project(project))
  end

  def test_for_project_defaults_to_the_mo_slip
    assert_instance_of(FieldSlip::Template::Mo,
                       FieldSlip::Template.for_project(
                         projects(:bolete_project)
                       ))
    assert_instance_of(FieldSlip::Template::Mo,
                       FieldSlip::Template.for_project(nil))
  end

  # The special fields every template names must be in its own field
  # table -- a label typo here would quietly break the review form.
  def test_special_fields_exist_in_each_template
    FieldSlip::Template::REGISTRY.each_key do |key|
      template = FieldSlip::Template.for(key)
      labels = template.fields.keys

      assert_includes(labels, template.name_field, key)
      assert_includes(labels, template.location_field, key)
      assert_includes(labels, template.inat_codes_field, key)
      assert_includes(labels, template.code_field, key)
    end
  end

  # Every template's prompt pieces must be present strings -- the
  # extractor builds its instructions from them (see
  # Extractor::Prompt). The NAMA slip's distinctive features are
  # pinned so a copy-paste from Dbg can't silently describe the
  # wrong form.
  def test_every_template_describes_its_layout_and_rules
    FieldSlip::Template::REGISTRY.each_key do |key|
      template = FieldSlip::Template.for(key)

      assert_kind_of(String, template.layout, key)
      assert_kind_of(String, template.field_rules, key)
    end

    nama = FieldSlip::Template.for(:nama)

    assert_match(%r{iNaturalist/MO box}, nama.layout)
    assert_match(/DNA and VCP labels/, nama.layout)
    assert_match(/sticker/, nama.field_rules)
    assert_match(/Substrate Detail/, nama.field_rules)
  end

  # ---------- iNat code detection ----------

  # Every template's iNat slot reads ids the same way (see
  # Template::Base::RAW_ID) -- MO's free-text Other Codes box included.
  def test_mo_inat_code_normalizes_like_any_other_template
    template = FieldSlip::Template.for(:mo)

    assert_equal("12345678", template.inat_code_in(" 12345678 "))
    assert_equal("388596423", template.inat_code_in("388 596 423"))
    assert_equal("388879492", template.inat_code_in("10:29 388879492"))
    assert_nil(template.inat_code_in("DBG-12345"))
    assert_not(template.inat_code?(nil))
  end

  # The DBG slip's box is dedicated to iNaturalist, so the id is
  # recognized even mixed with a username or timestamp; short digit
  # runs (clock times, dates) don't qualify.
  def test_dbg_inat_code_found_in_mixed_text
    template = FieldSlip::Template.for(:dbg)

    assert_equal("388879492", template.inat_code_in("10:29 388879492"))
    assert_equal("388879863", template.inat_code_in("388879863"))
    assert_nil(template.inat_code_in("10:29 am"))
    assert_nil(template.inat_code_in("someuser 8/6"))
  end

  # Every shape below is a real entry from the 2026 CMS fair scans:
  # collectors group the digits with spaces or dashes, prefix them, or
  # write them beside usernames and times.
  def test_dbg_inat_code_normalizes_separators
    template = FieldSlip::Template.for(:dbg)

    assert_equal("388596423", template.inat_code_in("388 596 423"))
    assert_equal("388401241", template.inat_code_in("388-401241"))
    assert_equal("389207996", template.inat_code_in("389-207-996"))
    assert_equal("389176438", template.inat_code_in("#389176438"))
    assert_equal("388891116",
                 template.inat_code_in("fungus_junkie iNat: 388891116"))
    assert_equal("389198780",
                 template.inat_code_in("1:59 pm 389-198-780 (iNat#) see Alex"))
    assert_nil(template.inat_code_in("gSanchez"))
    assert_nil(template.inat_code_in("1:58 PM"))
  end

  # The NAMA slip's box is "iNaturalist/MO": an MO observation number
  # written there (6 digits) stays below RAW_ID's 7-digit floor, so
  # only iNat-length ids are linked.
  def test_nama_inat_code_ignores_mo_observation_numbers
    template = FieldSlip::Template.for(:nama)

    assert_equal("389176438", template.inat_code_in("#389176438"))
    assert_equal("388596423", template.inat_code_in("388 596 423"))
    assert_nil(template.inat_code_in("MO 664471"))
    assert_nil(template.inat_code_in("someuser 10:29"))
  end
end
