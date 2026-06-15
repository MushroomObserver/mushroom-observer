# frozen_string_literal: true

require("test_helper")

class FormObject::TranslationTest < UnitTestCase
  def test_has_tag_attribute
    form = FormObject::Translation.new(tag: "app_title")

    assert_equal("app_title", form.tag)
  end

  def test_tag_defaults_to_nil
    form = FormObject::Translation.new

    assert_nil(form.tag)
  end

  def test_is_persisted
    form = FormObject::Translation.new(tag: "app_title")

    assert(form.persisted?)
  end

  def test_model_name
    assert_equal("Translation",
                 FormObject::Translation.model_name.name)
  end

  def test_param_key
    assert_equal("translation",
                 FormObject::Translation.model_name.param_key)
  end
end
