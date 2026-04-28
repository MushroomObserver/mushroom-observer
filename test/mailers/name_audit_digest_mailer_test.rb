# frozen_string_literal: true

require("test_helper")

class NameAuditDigestMailerTest < UnitTestCase
  def test_build_renders_subject_and_body
    receiver = users(:rolf)
    name_a = names(:coprinus_comatus)
    name_b = names(:agaricus_campestris)

    mail = NameAuditDigestMailer.build(
      receiver: receiver,
      name_ids: [name_a.id, name_b.id],
      audit_date: Time.zone.parse("2026-04-28")
    )

    assert_equal(1, mail.to.size)
    assert_includes(mail.to, receiver.email)
    assert_match(/Classification Updates/, mail.subject)
    assert_match(/2/, mail.subject)
    body = mail.body.to_s
    assert_match(%r{/names/#{name_a.id}/versions}, body)
    assert_match(%r{/names/#{name_b.id}/versions}, body)
    assert_match(%r{/names/#{name_a.id}\b}, body)
    assert_match(%r{/names/#{name_b.id}\b}, body)
  end

  def test_build_with_one_name
    receiver = users(:rolf)
    mail = NameAuditDigestMailer.build(
      receiver: receiver, name_ids: [names(:coprinus_comatus).id],
      audit_date: Time.zone.now
    )

    assert_match(/1/, mail.subject)
  end
end
