# frozen_string_literal: true

require("test_helper")

# Tests for Name::Notify (app/models/name/notify.rb)
class Name::NotifyTest < UnitTestCase
  include ActiveJob::TestHelper

  def test_email_notification
    name = names(:peltigera)
    desc = name_descriptions(:peltigera_desc)

    rolf.email_names_admin    = false
    rolf.email_names_author   = true
    rolf.email_names_editor   = true
    rolf.email_names_reviewer = true
    rolf.save

    mary.email_names_admin    = false
    mary.email_names_author   = true
    mary.email_names_editor   = false
    mary.email_names_reviewer = false
    mary.save

    dick.email_names_admin    = false
    dick.email_names_author   = false
    dick.email_names_editor   = false
    dick.email_names_reviewer = false
    dick.save

    katrina.email_names_admin    = false
    katrina.email_names_author   = true
    katrina.email_names_editor   = true
    katrina.email_names_reviewer = true
    katrina.save

    # Start with no reviewers, editors or authors.
    desc.gen_desc = ""
    desc.review_status = :unreviewed
    desc.reviewer = nil
    Name.without_revision do
      desc.save
    end
    desc.authors.clear
    desc.editors.clear
    desc.reload
    name_version = name.version
    description_version = desc.version

    assert_equal(0, desc.authors.length)
    assert_equal(0, desc.editors.length)
    assert_nil(desc.reviewer_id)

    # email types:  author  editor  review  interest
    # 1 Rolf:       x       x       x       .
    # 2 Mary:       x       .       .       .
    # 3 Dick:       .       .       .       .
    # 4 Katrina:    x       x       x       .
    # Authors: --        editors: --         reviewer: -- (unreviewed)
    # Rolf erases notes: no emails (no authors yet), Rolf becomes editor.
    desc.reload
    desc.current_user = rolf
    desc.gen_desc = ""
    desc.diag_desc = ""
    desc.distribution = ""
    desc.habitat = ""
    desc.look_alikes = ""
    desc.uses = ""
    assert_no_enqueued_jobs do
      desc.save
    end
    assert_equal(description_version + 1, desc.version)
    assert_equal(0, desc.authors.length)
    assert_equal(1, desc.editors.length)
    assert_nil(desc.reviewer_id)
    assert_equal(rolf, desc.editors.first)

    # email types:  author  editor  review  interest
    # 1 Rolf:       x       x       x       .
    # 2 Mary:       x       .       .       .
    # 3 Dick:       .       .       .       .
    # 4 Katrina:    x       x       x       .
    # Authors: --        editors: Rolf       reviewer: -- (unreviewed)
    # Mary writes gen_desc: notify Rolf (editor), Mary becomes author.
    desc.reload
    desc.current_user = mary
    assert_enqueued_with(
      job: ActionMailer::MailDeliveryJob,
      args: lambda { |args|
        mailer_args = args[3][:args].first
        args[0] == "NameChangeMailer" &&
          mailer_args[:sender] == mary &&
          mailer_args[:receiver] == rolf &&
          mailer_args[:name] == name &&
          mailer_args[:description] == desc &&
          mailer_args[:old_name_ver] == name.version &&
          mailer_args[:new_name_ver] == name.version &&
          mailer_args[:old_desc_ver] == description_version + 1 &&
          mailer_args[:new_desc_ver] == description_version + 2 &&
          mailer_args[:review_status] == "no_change"
      }
    ) do
      desc.gen_desc = "Mary wrote this."
      desc.save
    end
    assert_equal(description_version + 2, desc.version)
    assert_equal(1, desc.authors.length)
    assert_equal(1, desc.editors.length)
    assert_nil(desc.reviewer_id)
    assert_equal(mary, desc.authors.first)
    assert_equal(rolf, desc.editors.first)

    # Rolf doesn't want to be notified if people change names he's edited.
    rolf.email_names_editor = false
    rolf.save

    # email types:  author  editor  review  interest
    # 1 Rolf:       x       .       x       .
    # 2 Mary:       x       .       .       .
    # 3 Dick:       .       .       .       .
    # 4 Katrina:    x       x       x       .
    # Authors: Mary      editors: Rolf       reviewer: -- (unreviewed)
    # Dick changes uses: notify Mary (author); Dick becomes editor.
    desc.reload
    desc.current_user = dick
    assert_enqueued_with(
      job: ActionMailer::MailDeliveryJob,
      args: lambda { |args|
        mailer_args = args[3][:args].first
        args[0] == "NameChangeMailer" &&
          mailer_args[:sender] == dick &&
          mailer_args[:receiver] == mary &&
          mailer_args[:name] == name &&
          mailer_args[:description] == desc &&
          mailer_args[:old_name_ver] == name.version &&
          mailer_args[:new_name_ver] == name.version &&
          mailer_args[:old_desc_ver] == description_version + 2 &&
          mailer_args[:new_desc_ver] == description_version + 3 &&
          mailer_args[:review_status] == "no_change"
      }
    ) do
      desc.uses = "Something more new."
      desc.save
    end
    assert_equal(description_version + 3, desc.version)
    assert_equal(1, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_nil(desc.reviewer_id)
    assert_equal(mary, desc.authors.first)
    assert_equal([rolf.id, dick.id].sort, desc.editors.map(&:id).sort)

    # Mary opts out of author emails, add Katrina as new author.
    desc.add_author(katrina)
    mary.email_names_author = false
    mary.save

    # email types:  author  editor  review  interest
    # 1 Rolf:       x       .       x       .
    # 2 Mary:       .       .       .       .
    # 3 Dick:       .       .       .       .
    # 4 Katrina:    x       x       x       .
    # Authors: Mary,Katrina   editors: Rolf,Dick   reviewer: -- (unreviewed)
    # Rolf reviews name: notify Katrina (author), Rolf becomes reviewer.
    desc.reload
    desc.current_user = rolf
    assert_enqueued_with(
      job: ActionMailer::MailDeliveryJob,
      args: lambda { |args|
        mailer_args = args[3][:args].first
        args[0] == "NameChangeMailer" &&
          mailer_args[:sender] == rolf &&
          mailer_args[:receiver] == katrina &&
          mailer_args[:name] == name &&
          mailer_args[:description] == desc &&
          mailer_args[:old_name_ver] == name.version &&
          mailer_args[:new_name_ver] == name.version &&
          # NOTE: update_review_status doesn't create a new version
          mailer_args[:old_desc_ver] == description_version + 3 &&
          mailer_args[:new_desc_ver] == description_version + 3 &&
          mailer_args[:review_status] == "inaccurate"
      }
    ) do
      desc.update_review_status("inaccurate")
    end
    assert_equal(description_version + 3, desc.version)
    assert_equal(2, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_equal(rolf.id, desc.reviewer_id)
    assert_equal([mary.id, katrina.id].sort, desc.authors.map(&:id).sort)
    assert_equal([rolf.id, dick.id].sort, desc.editors.map(&:id).sort)

    # Have Katrina express disinterest.
    Interest.create(target: name, user: katrina, state: false)

    # email types:  author  editor  review  interest
    # 1 Rolf:       x       .       x       .
    # 2 Mary:       .       .       .       .
    # 3 Dick:       .       .       .       .
    # 4 Katrina:    x       x       x       no
    # Authors: Mary,Katrina   editors: Rolf,Dick   reviewer: Rolf (inaccurate)
    # Dick changes look-alikes: notify Rolf (reviewer), clear review status
    desc.reload
    desc.current_user = dick
    assert_enqueued_with(
      job: ActionMailer::MailDeliveryJob,
      args: lambda { |args|
        mailer_args = args[3][:args].first
        args[0] == "NameChangeMailer" &&
          mailer_args[:sender] == dick &&
          mailer_args[:receiver] == rolf &&
          mailer_args[:name] == name &&
          mailer_args[:description] == desc &&
          mailer_args[:old_name_ver] == name.version &&
          mailer_args[:new_name_ver] == name.version &&
          mailer_args[:old_desc_ver] == description_version + 3 &&
          mailer_args[:new_desc_ver] == description_version + 4 &&
          mailer_args[:review_status] == "unreviewed"
      }
    ) do
      desc.look_alikes = "Dick added this -- it's suspect"
      # (This is exactly what is normally done by name controller in edit_name.
      # Yes, Dick isn't actually trying to review, and isn't even a reviewer.
      # The point is to update the review date if Dick *were*, or reset the
      # status to unreviewed in the present case that he *isn't*.)
      desc.update_review_status("inaccurate")
      desc.save
    end
    assert_equal(description_version + 4, desc.version)
    assert_equal(2, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_equal("unreviewed", desc.review_status)
    assert_nil(desc.reviewer_id)
    assert_equal([mary.id, katrina.id].sort, desc.authors.map(&:id).sort)
    assert_equal([rolf.id, dick.id].sort, desc.editors.map(&:id).sort)

    # Mary expresses interest.
    Interest.create(target: name, user: mary, state: true)

    # email types:  author  editor  review  interest
    # 1 Rolf:       x       .       x       .
    # 2 Mary:       .       .       .       yes
    # 3 Dick:       .       .       .       .
    # 4 Katrina:    x       x       x       no
    # Authors: Mary,Katrina   editors: Rolf,Dick   reviewer: Rolf (unreviewed)
    # Rolf changes citation (on Name, not desc): notify Mary (interest).
    name.reload
    assert_enqueued_with(
      job: ActionMailer::MailDeliveryJob,
      args: lambda { |args|
        mailer_args = args[3][:args].first
        args[0] == "NameChangeMailer" &&
          mailer_args[:sender] == rolf &&
          mailer_args[:receiver] == mary &&
          mailer_args[:name] == name &&
          mailer_args[:description].nil? &&
          mailer_args[:old_name_ver] == name_version &&
          mailer_args[:new_name_ver] == name_version + 1 &&
          mailer_args[:old_desc_ver].zero? &&
          mailer_args[:new_desc_ver].zero? &&
          mailer_args[:review_status] == "no_change"
      }
    ) do
      name.citation = "Rolf added this."
      name.current_user = rolf
      name.save
    end
    assert_equal(name_version + 1, name.version)
    assert_equal(description_version + 4, desc.version)
    assert_equal(2, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_nil(desc.reviewer_id)
    assert_equal([mary.id, katrina.id].sort, desc.authors.map(&:id).sort)
    assert_equal([rolf.id, dick.id].sort, desc.editors.map(&:id).sort)
  end

  def test_notify_interest_state_false
    # Test Interest with state=false removes user from recipients
    name = names(:peltigera)
    desc = name_descriptions(:peltigera_desc)

    # Mary is author, rolf is editor - both would normally be notified
    Name.without_revision do
      desc.authors.clear
      desc.editors.clear
    end
    desc.authors << mary
    desc.editors << rolf

    mary.update!(email_names_author: true)
    rolf.update!(email_names_editor: true)
    dick.update!(email_names_editor: false, email_names_author: false)

    # Dick creates Interest with state=false - explicitly opts out
    Interest.where(target: name).destroy_all
    Interest.create!(user: dick, target: name, state: false)

    # Katrina makes a change - should notify mary and rolf, but NOT dick
    name.reload

    # Should enqueue 2 emails (mary and rolf), not 3 (dick was removed
    # because of Interest with state=false, and Katrina is excluded
    # from her own notification as `current_user`/sender)
    assert_enqueued_jobs(2) do
      name.citation = "Katrina added citation."
      name.current_user = katrina
      name.save
    end

    Interest.where(target: name).destroy_all
  end

  def test_skip_notify
    name = names(:coprinus_comatus)
    name.skip_notify = true
    assert_no_enqueued_jobs do
      name.update(
        Name.parse_name("Coprinus comatus  (O.F. Müll.) Persoon").params
      )
    end
    name.skip_notify = false
    assert_enqueued_jobs(2) do
      name.update(
        Name.parse_name("Coprinus comatus  (O.F. Müll.) Pers.").params
      )
    end
  end

  def test_classification_only_save_does_not_notify
    name = names(:coprinus_comatus)
    new_cls = "Domain: _Eukarya_\r\nKingdom: _Fungi_\r\n" \
              "Phylum: _TestPhylum_\r\n"
    assert_not_equal(new_cls, name.classification)

    assert_no_enqueued_jobs do
      name.update(classification: new_cls)
    end
  end

  def test_notify_webmaster
    # Test notify_webmaster sends email via deliver_later
    name = Name.new(
      text_name: "Testname webmaster",
      display_name: "**__Testname webmaster__**",
      user: rolf
    )

    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      name.notify_webmaster
    end
  end

  def test_notify_webmaster_skip_notify
    # Test that skip_notify prevents notify_webmaster
    name = Name.new(
      text_name: "Testname skip",
      display_name: "**__Testname skip__**",
      user: rolf
    )
    name.skip_notify = true

    assert_no_enqueued_jobs do
      name.notify_webmaster
    end
  end
end
