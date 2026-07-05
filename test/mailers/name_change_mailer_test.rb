# frozen_string_literal: true

require("test_helper")

class NameChangeMailerTest < MailerTestCase
  def test_build_change_html
    name = names(:peltigera)
    desc = name.description
    mary.update!(email_html: true)

    mail = NameChangeMailer.build(
      sender: dick, receiver: mary, name:,
      old_name_ver: name.version - 1, new_name_ver: name.version,
      description: desc, old_desc_ver: desc.version - 1,
      new_desc_ver: desc.version, review_status: desc.review_status.to_s
    ).message

    assert_includes(mail.to, mary.email)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "https://mushroomobserver.org/names/#{name.id}")
  end

  def test_build_change_text
    name = names(:peltigera)
    desc = name.description
    mary.update!(email_html: false)

    mail = NameChangeMailer.build(
      sender: dick, receiver: mary, name:,
      old_name_ver: name.version - 1, new_name_ver: name.version,
      description: desc, old_desc_ver: desc.version - 1,
      new_desc_ver: desc.version, review_status: desc.review_status.to_s
    ).message

    assert_text_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "-" * 50)
    assert_includes(body, "https://mushroomobserver.org/names/#{name.id}")
  end

  def test_build_new_name_text
    name = names(:peltigera)
    desc = name.description
    mary.update!(email_html: false)

    mail = NameChangeMailer.build(
      sender: dick, receiver: mary, name:,
      old_name_ver: 0, new_name_ver: 1,
      description: desc, old_desc_ver: 0, new_desc_ver: 1,
      review_status: "no_change"
    ).message

    assert_text_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "was created")
    assert_includes(body, "https://mushroomobserver.org/names/#{name.id}")
  end

  # Name version unchanged, only the description changed — hits the
  # `elsif (new_desc = desc_change.new_clone)` branch of
  # name_email_type, distinct from test_build_change_*'s "name
  # itself changed" branch. rolf is peltigera_desc's reviewer and
  # has email_names_reviewer on, so this also confirms
  # permission_reason resolves to "reviewer".
  def test_build_desc_only_change
    name = names(:peltigera)
    desc = name.description
    rolf.update!(email_html: false)

    mail = NameChangeMailer.build(
      sender: dick, receiver: rolf, name:,
      old_name_ver: name.version, new_name_ver: name.version,
      description: desc, old_desc_ver: desc.version - 1,
      new_desc_ver: desc.version, review_status: "no_change"
    ).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "type=names_reviewer")
  end

  # correct_spelling_liner's "no correct spelling" ("--") fallback —
  # easier to reach by rendering the Text view directly against a
  # fabricated name_change (two in-memory copies of the same fixture
  # differing only in correct_spelling_id) than by hunting for real
  # version history where a name's correct_spelling was cleared.
  def test_correct_spelling_removed_renders_dash
    old_name = Name.find(names(:peltigera).id)
    old_name.correct_spelling_id = names(:coprinus_comatus).id
    new_name = Name.find(names(:peltigera).id)
    new_name.correct_spelling_id = nil

    html = render(Views::Mailers::NameChangeMailer::Text.new(
                    subject: "test", receiver: rolf, sender: dick,
                    time: Time.zone.now,
                    name_change: fake_change(old_name, new_name),
                    desc_change: fake_change(nil, nil),
                    watching: false, email_type: nil
                  ))

    assert_includes(html, "--")
  end

  # PERMISSION_REASONS checks admin before editor/author/reviewer — a
  # receiver qualifying for multiple reasons should be reported as
  # "admin" so the "stop sending" link they see actually stops the
  # notification, rather than leaving them still subscribed via the
  # narrower role.
  def test_build_desc_only_change_admin_wins_over_editor
    name = names(:peltigera)
    desc = name.description
    desc.admin_groups << UserGroup.one_user(dick)
    desc.add_editor(dick)
    dick.update!(email_names_admin: true, email_names_editor: true,
                 email_html: false)

    mail = NameChangeMailer.build(
      sender: rolf, receiver: dick, name:,
      old_name_ver: name.version, new_name_ver: name.version,
      description: desc, old_desc_ver: desc.version - 1,
      new_desc_ver: desc.version, review_status: "no_change"
    ).message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "type=names_admin")
  end

  private

  def fake_change(old_clone, new_clone)
    change = ObjectChange.allocate
    change.instance_variable_set(:@old_clone, old_clone)
    change.instance_variable_set(:@new_clone, new_clone)
    change
  end
end
