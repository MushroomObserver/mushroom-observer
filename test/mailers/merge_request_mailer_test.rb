# frozen_string_literal: true

require("test_helper")

class MergeRequestMailerTest < MailerTestCase
  def test_build_for_name
    name1 = names(:agaricus_campestris)
    name2 = names(:boletus_edulis)
    user = users(:rolf)

    mail = build_mail(old_obj: name1, new_obj: name2, user: user,
                      notes: "please merge")

    assert_includes(mail.to, MO.webmaster_email_address)
    assert_equal(user.email, mail.reply_to.first)
    assert_text_mail(mail)
    body = mail.body.to_s
    assert_match(/#{Regexp.escape(name1.real_search_name)}/, body)
    assert_match(/#{Regexp.escape(name2.real_search_name)}/, body)
    assert_includes(body, "please merge")
    assert_includes(body, user.login)
  end

  def test_build_for_location
    loc1 = locations(:albion)
    loc2 = locations(:burbank)
    user = users(:mary)

    mail = build_mail(old_obj: loc1, new_obj: loc2, user: user,
                      notes: "loc merge")

    body = mail.body.to_s
    assert_match(/#{Regexp.escape(loc1.name)}/, body)
    assert_match(/#{Regexp.escape(loc2.name)}/, body)
    assert_includes(body, "loc merge")
  end

  def test_build_for_herbarium
    herb1 = herbaria(:nybg_herbarium)
    herb2 = herbaria(:fundis_herbarium)
    user = users(:mary)

    mail = build_mail(old_obj: herb1, new_obj: herb2, user: user,
                      notes: "herb merge")

    body = mail.body.to_s
    assert_match(/#{Regexp.escape(herb1.name)}/, body)
    assert_match(/#{Regexp.escape(herb2.name)}/, body)
    assert_includes(body, "herb merge")
  end

  # MergeRequestMailer#build's I18n.locale line is what actually governs
  # resolution (the Phlex view render happens inside build's own call,
  # not synchronously in whatever locale the caller happened to be in) --
  # confirm it resolves in MO.default_locale even under a different
  # ambient locale. :de may not be I18n-available on CI (see
  # with_expanded_locales in test_helper.rb), hence the wrapper.
  def test_build_resolves_in_default_locale_regardless_of_ambient_locale
    loc1 = locations(:albion)
    loc2 = locations(:burbank)

    mail = with_expanded_locales(:de) do
      I18n.with_locale(:de) do
        build_mail(old_obj: loc1, new_obj: loc2, user: users(:mary),
                   notes: "x")
      end
    end

    expected_label = I18n.with_locale(MO.default_locale) { :location.ti }
    assert_match(/#{Regexp.escape(expected_label)}/, mail.body.to_s)
  end

  private

  def build_mail(old_obj:, new_obj:, user:, notes:)
    MergeRequestMailer.build(
      sender_email: user.email, old_obj:, new_obj:, user:, notes:
    ).message
  end
end
