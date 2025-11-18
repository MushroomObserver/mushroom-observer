# frozen_string_literal: true

require("test_helper")

class FormObject::LoginTest < UnitTestCase
  def test_has_login_attribute
    form = FormObject::Login.new(login: "testuser")

    assert_equal("testuser", form.login)
  end

  def test_has_password_attribute
    form = FormObject::Login.new(password: "secret")

    assert_equal("secret", form.password)
  end

  def test_has_remember_me_attribute
    form = FormObject::Login.new(remember_me: true)

    assert(form.remember_me)
  end

  def test_remember_me_defaults_to_false
    form = FormObject::Login.new

    assert_not(form.remember_me)
  end

  def test_model_name_is_user
    assert_equal("User", FormObject::Login.model_name.name)
  end

  def test_param_key_is_user
    assert_equal("user", FormObject::Login.model_name.param_key)
  end

  def test_not_persisted
    form = FormObject::Login.new

    assert_not(form.persisted?)
  end
end
