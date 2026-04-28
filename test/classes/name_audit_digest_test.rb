# frozen_string_literal: true

require("test_helper")

class NameAuditDigestTest < UnitTestCase
  include ActionMailer::TestHelper

  def setup
    super
    @sender = users(:webmaster)
    @author = users(:rolf)
    @editor = users(:mary)
    @bystander = users(:dick)
    User.current = @author
    @name = NameAuditDigestTestHelper.fresh_name("Auditspecies primus")
    @other_name = NameAuditDigestTestHelper.fresh_name("Auditspecies secundus")
    NameAuditDigestTestHelper.attach_description(@name, @author, @editor)
    NameAuditDigestTestHelper.attach_description(@other_name, @author,
                                                 @editor)
  end

  def test_recipients_includes_author
    rec = NameAuditDigest.recipients(name_ids: [@name.id, @other_name.id],
                                     sender: @sender)

    assert_includes(rec.keys, @author.id)
    assert_equal(Set[@name.id, @other_name.id], rec[@author.id])
  end

  def test_recipients_excludes_admin_when_admin_flag_off
    @author.update!(email_names_admin: false)
    @author.update!(email_names_author: false)
    rec = NameAuditDigest.recipients(name_ids: [@name.id], sender: @sender)

    assert_not_includes(rec.keys, @author.id)
  end

  def test_recipients_excludes_user_with_no_emails
    @author.update!(no_emails: true)
    rec = NameAuditDigest.recipients(name_ids: [@name.id], sender: @sender)

    assert_not_includes(rec.keys, @author.id)
  end

  def test_recipients_excludes_sender
    sender = @author
    rec = NameAuditDigest.recipients(name_ids: [@name.id], sender: sender)

    assert_not_includes(rec.keys, sender.id)
  end

  def test_recipients_dedups_user_with_multiple_roles
    @author.update!(email_names_editor: true)
    rec = NameAuditDigest.recipients(name_ids: [@name.id], sender: @sender)

    assert_equal(Set[@name.id], rec[@author.id])
  end

  def test_recipients_includes_interested_user
    Interest.create!(target: @name, user: @bystander, state: true)
    rec = NameAuditDigest.recipients(name_ids: [@name.id], sender: @sender)

    assert_equal(Set[@name.id], rec[@bystander.id])
  end

  def test_recipients_negative_interest_removes_user_from_that_name
    Interest.create!(target: @name, user: @author, state: false)
    rec = NameAuditDigest.recipients(name_ids: [@name.id, @other_name.id],
                                     sender: @sender)

    assert_equal(Set[@other_name.id], rec[@author.id])
  end

  def test_recipients_empty_when_no_name_ids
    assert_empty(NameAuditDigest.recipients(name_ids: [], sender: @sender))
  end

  def test_recipients_empty_when_no_affected_users
    plain = NameAuditDigestTestHelper.fresh_name("Bareus solus")
    rec = NameAuditDigest.recipients(name_ids: [plain.id], sender: @sender)

    assert_empty(rec)
  end

  def test_send_digests_enqueues_one_email_per_recipient
    Interest.create!(target: @name, user: @bystander, state: true)

    assert_enqueued_emails(2) do
      count = NameAuditDigest.send_digests(
        name_ids: [@name.id], sender: @sender
      )
      assert_equal(2, count)
    end
  end

  def test_send_digests_enqueues_nothing_when_no_recipients
    plain = NameAuditDigestTestHelper.fresh_name("Bareus duo")

    assert_enqueued_emails(0) do
      count = NameAuditDigest.send_digests(
        name_ids: [plain.id], sender: @sender
      )
      assert_equal(0, count)
    end
  end
end

# Test helper kept here so the fixture-light setup stays close to the
# tests that use it. Creates a fresh Name with no pre-existing
# descriptions, then registers the given user as an author/editor
# (defaults: email_names_author=true, email_names_editor=false, so
# only the author is on the recipients list unless test enables the
# editor flag).
module NameAuditDigestTestHelper
  def self.fresh_name(text_name)
    Name.create!(text_name: text_name, search_name: "#{text_name} L.",
                 sort_name: "#{text_name} L.",
                 display_name: "**__#{text_name}__** L.",
                 author: "L.", rank: "Species", deprecated: false,
                 user: User.current || User.first)
  end

  def self.attach_description(name, author, editor)
    desc = name.descriptions.first || NameDescription.create!(
      name: name, user: author, source_type: :public, public: true
    )
    desc.add_author(author) unless desc.authors.include?(author)
    desc.add_editor(editor) unless desc.editors.include?(editor)
  end
end
