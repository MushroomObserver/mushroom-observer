# frozen_string_literal: true

require("test_helper")

class UserTest < UnitTestCase
  def test_auth
    assert_equal(rolf,
                 User.authenticate(login: "rolf", password: "testpassword"))
    assert_nil(User.authenticate(login: "nonrolf", password: "testpassword"))
  end

  def test_password_change
    mary.change_password("marypasswd")
    assert_equal(mary, User.authenticate(login: "mary", password: "marypasswd"))
    assert_nil(User.authenticate(login: "mary", password: "longtest"))
    mary.change_password("longtest")
    assert_equal(mary, User.authenticate(login: "mary", password: "longtest"))
    assert_nil(User.authenticate(login: "mary", password: "marypasswd"))
  end

  def test_disallowed_passwords
    u = User.new
    u.login = "nonbob"
    u.email = "nonbob@collectivesource.com"
    u.theme = "NULL"
    u.notes = ""
    u.mailing_address = ""

    u.password = u.password_confirmation = "tiny"
    assert_not(u.save)
    assert(u.errors[:password].any?)

    u.password = u.password_confirmation = "huge" * 43 # size = 4 * 43 == 172
    assert_not(u.save)
    assert(u.errors[:password].any?)

    u.password = "unconfirmed_password"
    u.password_confirmation = ""
    assert_not(u.save)
    assert(u.errors[:password].any?)

    # This is allowed now to let API create users without a password chosen yet.
    u.password = u.password_confirmation = "bobs_secure_password"
    assert(u.save)
    assert(u.errors.empty?)
  end

  def test_bad_logins
    u = User.new
    u.password = u.password_confirmation = "bobs_secure_password"
    u.email = "bob@collectivesource.com"
    u.theme = "NULL"
    u.notes = ""
    u.mailing_address = ""

    u.login = "x"
    assert_not(u.save)
    assert(u.errors[:login].any?)

    u.login = "hugebob" * 26 # size = 7 * 26 == 182
    assert_not(u.save)
    assert(u.errors[:login].any?)

    u.login = ""
    assert_not(u.save)
    assert(u.errors[:login].any?)

    u.login = "okbob"
    assert(u.save)
    assert(u.errors.empty?)
  end

  def test_collision
    u       = User.new
    u.login = "rolf"
    u.email = "rolf@collectivesource.com"
    u.theme = "NULL"
    u.notes = ""
    u.mailing_address = ""
    u.password = u.password_confirmation = "rolfs_secure_password"
    assert_not(u.save)
  end

  def test_create
    u       = User.new
    u.login = "nonexistingbob"
    u.email = "nonexistingbob@collectivesource.com"
    u.theme = "NULL"
    u.notes = ""
    u.mailing_address = ""
    u.password = u.password_confirmation = "bobs_secure_password"
    u.email = "nonexistingbob@collectivesource.com"
    assert(u.save)
  end

  def test_sha1
    u = User.new
    u.login = "nonexistingbob"
    u.password = u.password_confirmation = "bobs_secure_password"
    u.email = "nonexistingbob@collectivesource.com"
    u.theme = "NULL"
    u.notes = ""
    u.mailing_address = ""
    assert(u.save)
    assert_equal("74996ba5c4aa1d583563078d8671fef076e2b466", u.password)
  end

  def test_meta_groups
    all = User.all
    group1 = UserGroup.all_users
    assert_user_arrays_equal(all, group1.users, :sort)

    user = User.create!(
      password: "blah!",
      password_confirmation: "blah!",
      login: "bobby",
      email: "bob@bigboy.com",
      theme: nil,
      notes: "",
      mailing_address: ""
    )
    UserGroup.create_user(user)

    group1.reload
    group2 = UserGroup.one_user(user)
    assert_user_arrays_equal(all + [user], group1.users, :sort)
    assert_user_arrays_equal([user], group2.users, :sort)

    UserGroup.destroy_user(user)
    user.destroy
    group1.reload
    group2.reload # not destroyed, just empty
    assert_user_arrays_equal(all, group1.users, :sort)
    assert_user_arrays_equal([], group2.users, :sort)
  end

  # Bug seen in the wild: myxomop created a username which was just under 80
  # characters long, but which had a few accents, so it was > 80 *bytes* long,
  # and it truncated right in the middle of a utf-8 sequence.  Broke the front
  # page of the site for several minutes.
  #
  # In the combination of newer versions of Ruby, Rails, MySQL,
  # and MySQL drivers, truncate should not truncate in the middle of a
  # multi-byte character, so this should no longer be a problem.
  # The string was:
  #   Herbario Forestal Nacional Martín Cárdenas de la Universidad Mayor \
  #   de San Simón
  # And this string is, in fact in the db as a user name, without truncation
  # Test has been revised accordingly.
  # 2017-06-16 JDC
  def test_myxomops_debacle
    # rubocop:disable Layout/LineLength
    name_79_chars_82_bytes = "Herbario Forestal Nacional Martín Cárdenas de la Universidad Mayor de San Simón"
    name_90_chars_93_bytes = "Herbario Forestal Nacional de Bolivia Martín Cárdenas de la Universidad Mayor de San Simón"
    # rubocop:enable Layout/LineLength

    mary.name = name_90_chars_93_bytes
    assert_not(mary.save)
    mary.name = name_79_chars_82_bytes
    assert(mary.save)
    mary.reload
    assert_equal(name_79_chars_82_bytes, mary.name)
  end

  def test_all_editable_species_lists
    proj = projects(:bolete_project)
    assert_true(proj.user_group.users.include?(dick))
    assert_true(proj.user_group.users.include?(mary))

    proj_spl = proj.species_lists.find_by(user: mary)
    assert_false(rolf.all_editable_species_lists.include?(proj_spl))
    assert_true(mary.all_editable_species_lists.include?(proj_spl))
    assert_true(dick.all_editable_species_lists.include?(proj_spl))

    rolf_spl = (rolf.species_lists - proj.species_lists)[0]
    assert_false(dick.all_editable_species_lists.include?(rolf_spl))
    assert_false(mary.all_editable_species_lists.include?(rolf_spl))

    proj.add_species_list(rolf_spl)
    dick.reload
    mary.reload
    assert_true(dick.all_editable_species_lists.include?(rolf_spl))
    assert_true(mary.all_editable_species_lists.include?(rolf_spl))

    proj.user_group.users.push(rolf)
    proj.user_group.users.delete(dick)
    rolf.reload
    mary.reload
    dick.reload

    rolf_lists = rolf.all_editable_species_lists
    assert_true(rolf_lists.include?(proj_spl))
    assert_true(rolf_lists.include?(rolf_spl))

    mary_lists = mary.all_editable_species_lists
    assert_true(mary_lists.include?(proj_spl))
    assert_true(mary_lists.include?(rolf_spl))

    dick_lists = dick.all_editable_species_lists
    assert_false(dick_lists.include?(proj_spl))
    assert_false(dick_lists.include?(rolf_spl))
  end

  def test_preferred_herbarium_name
    assert_equal(herbaria(:nybg_herbarium).name, rolf.preferred_herbarium_name)
    assert_equal(herbaria(:fundis_herbarium).name,
                 mary.preferred_herbarium_name)
  end

  def test_remove_image
    image = rolf.image
    assert(image)
    rolf.remove_image(image)
    rolf.reload
    assert_nil(rolf.image)
  end

  def test_erase_user
    user = users(:spammer)
    user_id = user.id
    group_id = UserGroup.one_user(user_id).id
    pub_id = user.publications[0].id
    User.erase_user(user_id)
    assert_raises(ActiveRecord::RecordNotFound) { User.find(user_id) }
    assert_raises(ActiveRecord::RecordNotFound) { UserGroup.find(group_id) }
    assert_not(UserGroup.all_users.user_ids.include?(user_id))
    assert_raises(ActiveRecord::RecordNotFound) { Publication.find(pub_id) }
  end

  def test_erase_user_with_comment_and_name_descriptions
    user = dick
    num_comments = Comment.count
    assert_equal(1, user.comments.length)
    comment_id = user.comments.first.id
    num_name_descriptions = NameDescription.count
    assert(user.name_descriptions.length > 1)
    sample_name_description_id = user.name_descriptions.first.id
    herbarium = user.personal_herbarium
    assert_not_nil(herbarium.personal_user)
    User.erase_user(user.id)
    assert_equal(num_comments - 1, Comment.count)
    assert_raises(ActiveRecord::RecordNotFound) { Comment.find(comment_id) }
    assert_equal(num_name_descriptions, NameDescription.count)
    desc = NameDescription.find(sample_name_description_id)
    assert_equal(0, desc.user_id)
    assert_equal(0, herbarium.reload.personal_user_id)
  end

  def test_erase_user_with_observation
    user = katrina
    num_observations = Observation.count
    num_namings = Naming.count
    num_votes = Vote.count
    num_images = Image.count
    num_comments = Comment.count
    num_publications = Publication.count

    # Find one of Katrina's observations.
    assert_equal(2, user.observations.length)
    observation = user.observations.find_by(gps_hidden: false)
    observation_id = observation.id

    # Attach her image to the observation.
    image = user.images.first
    image.observations << observation
    image.save
    image_id = image.id
    assert_equal(1, image.observations.length)
    assert_equal(observation_id, image.observations.first.id)

    # Move some other user's comment over to make sure they get deleted, too.
    assert_equal(1, katrina.comments.length)
    comment_id = katrina.comments.first.id

    # Fixtures have one vote for this observation,
    # but the naming the vote refers to applies to another observation!
    vote = observation.votes.first
    vote_id = vote.id
    naming = vote.naming
    naming.observation_id = observation.id
    naming.save
    naming_id = naming.id

    # Give her one publication, too, since I had to disable test_erase_user.
    publication = Publication.first
    publication_id = publication.id
    publication.user_id = user.id
    publication.save

    User.erase_user(user.id)

    # Should have deleted one of each type of object.
    assert_equal(num_observations - 2, Observation.count)
    assert_equal(num_namings - 1, Naming.count)
    assert_equal(num_votes - 1, Vote.count)
    assert_equal(num_images - 1, Image.count)
    assert_equal(num_comments - 1, Comment.count)
    assert_equal(num_publications - 1, Publication.count)
    assert_raises(ActiveRecord::RecordNotFound) do
      Observation.find(observation_id)
    end
    assert_raises(ActiveRecord::RecordNotFound) { Naming.find(naming_id) }
    assert_raises(ActiveRecord::RecordNotFound) { Vote.find(vote_id) }
    assert_raises(ActiveRecord::RecordNotFound) { Image.find(image_id) }
    assert_raises(ActiveRecord::RecordNotFound) { Comment.find(comment_id) }
    assert_raises(ActiveRecord::RecordNotFound) do
      Publication.find(publication_id)
    end
  end

  def test_successful_contributor?
    assert(rolf.successful_contributor?)
  end

  def test_is_unsuccessful_contributor?
    assert_false(users(:spammer).successful_contributor?)
  end

  def test_notes_template_validation
    u = User.new(
      login: "nonexistingbob",
      email: "nonexistingbob@collectivesource.com",
      theme: "NULL",
      notes: "",
      mailing_address: "",
      password: "bobs_secure_password",
      password_confirmation: "bobs_secure_password"
    )
    assert(u.valid?, "Nil notes template should be valid")

    u.notes_template = ""
    assert(u.valid?, "Empty notes template should be valid")

    u.notes_template = "Cap, Stem"
    assert(u.valid?, "Notes template present should be valid")

    u.notes_template = "Cap, Stem, Other"
    assert(u.invalid?, "Notes template with 'Other' should be invalid")

    u.notes_template = "Blah, Blah"
    assert(u.invalid?,
           "Notes template with duplication headings should be invalid")
  end

  def test_disable_account
    rolf.disable_account
    rolf.reload
    assert_blank(rolf.password)
    assert_blank(rolf.email)
    assert_blank(rolf.mailing_address)
    assert_blank(rolf.notes)
    assert_true(rolf.blocked)
  end

  def test_delete_api_keys
    assert_operator(0, "<", APIKey.where(user: rolf).count)
    rolf.delete_api_keys
    assert_equal(0, APIKey.where(user: rolf).count)
  end

  def test_delete_interests
    assert_operator(0, "<", Interest.where(user: junk).count)
    junk.delete_interests
    assert_equal(0, Interest.where(user: junk).count)
  end

  def test_delete_name_trackers
    assert_operator(0, "<", NameTracker.where(user: rolf).count)

    rolf.delete_name_trackers
    assert_equal(0, NameTracker.where(user: rolf).count)
  end

  def test_delete_queued_emails
    QueuedEmail.create(rolf, mary)
    QueuedEmail.create(mary, rolf)
    assert_operator(0, "<", QueuedEmail.where(user: rolf).count)
    assert_operator(0, "<", QueuedEmail.where(to_user: rolf).count)

    rolf.delete_queued_emails
    assert_equal(0, QueuedEmail.where(user: rolf).count)
    assert_equal(0, QueuedEmail.where(to_user: rolf).count)
  end

  def test_delete_observations
    assert_operator(0, "<", Observation.where(user: rolf).count)
    rolf.delete_observations
    assert_equal(0, Observation.where(user: rolf).count)
  end

  def test_delete_private_name_descriptions
    # All Rolf's descriptions should be "private" but these two:
    # Created by rolf, but katrina is author and editor.
    desc1 = name_descriptions(:coprinus_desc)
    # Created and authored by rolf, but mary is also editor.
    desc2 = name_descriptions(:coprinus_comatus_desc)
    assert_operator(2, "<", NameDescription.where(user: rolf).count)

    rolf.delete_private_name_descriptions
    assert_obj_arrays_equal(NameDescription.where(user: rolf).to_a,
                            [desc1, desc2], :sort)

    # All of Dick's should be deletable but for this one:
    # Rolf has one of the versions of this one.
    desc3 = name_descriptions(:peltigera_desc)
    assert_operator(0, "<", desc3.versions.where(user_id: rolf.id).count)

    dick.delete_private_name_descriptions
    assert_equal(1, NameDescription.where(user: dick).count,
                 "Failed to delete some NameDescriptions created by dick")
    # Make sure it left Dick's versions of the undeleted description.
    assert_operator(0, "<", NameDescription::Version.where(
      user_id: dick.id,
      name_description_id: desc3.id
    ).count)

    # But should be able to delete it if Dick owns all the versions.
    desc3.versions.update_all(user_id: dick.id)
    dick.delete_private_name_descriptions
    assert_equal(0, NameDescription.where(user: dick).count,
                 "Failed to delete last NameDescription created by dick")
    assert_equal(0, NameDescription::Version.where(
      name_description_id: desc3.id
    ).count)
  end

  def test_delete_private_location_descriptions
    # Rolf owns this description and all its versions, but let's add Dick
    # as an editor to make it non-private.
    albion = location_descriptions(:albion_desc)
    albion.editors << dick
    assert_users_equal(rolf, albion.user)
    assert_operator(1, "<", albion.versions.count)
    assert(albion.versions.all? { |ver| ver.user_id == rolf.id })

    # Can't delete while Dick is an editor.
    rolf.delete_private_location_descriptions
    assert_not_empty(LocationDescription.where(id: albion.id))

    # Let's remove Dick from the editors, but give one of the versions to Dick.
    albion.editors.clear
    albion.versions.update_all(user_id: dick.id)
    rolf.reload.delete_private_location_descriptions
    assert_not_nil(LocationDescription.find(albion.id))

    # Now give all the versions back to Rolf so we can finally delete it.
    albion.versions.update_all(user_id: rolf.id)
    rolf.reload.delete_private_location_descriptions
    assert_raises(ActiveRecord::RecordNotFound) \
      { LocationDescription.find(albion.id) }
    assert_equal(0, LocationDescription::Version.where(
      location_description_id: albion.id
    ).count)
  end

  def test_delete_private_projects
    # Dick created several projects.  Most have the admin and member groups set
    # to dick_only, but one uses albion_admins/albion_users, and another uses
    # article_writers.  The latter group contains users other than Dick, and
    # therefore that project (news_article_project) should not be deleted.

    # Prove that Dick owns a few projects using only dick_only.
    dick_only = user_groups(:dick_only)
    assert_operator(1, "<",
                    dick.projects_created.where(admin_group: dick_only,
                                                user_group: dick_only).count,
                    "dick should own at least two dick-only projects")

    # Prove that Dick owns albion_project and that its admins and users are
    # all just Dick despite not being his one-user group, dick_only.
    albion = projects(:albion_project)
    albion_admins = user_groups(:albion_admins)
    albion_users = user_groups(:albion_users)
    assert_users_equal(dick, albion.user)
    assert_equal(1, albion_admins.users.count)
    assert_equal(1, albion_users.users.count)
    assert_users_equal(dick, albion_admins.users.first)
    assert_users_equal(dick, albion_users.users.first)

    # Prove that Dick owns news_article_project but that the admin and user
    # is someone else.
    news_articles = projects(:news_articles_project)
    article_writers = user_groups(:article_writers)
    assert_users_equal(dick, news_articles.user)
    assert_operator(0, "<",
                    article_writers.users.count { |user| user != dick },
                    "article_writers should have a user other than dick")

    dick.delete_private_projects
    assert_empty(Project.where(id: albion.id))
    assert_not_empty(Project.where(id: news_articles.id))
  end

  def test_delete_private_species_lists
    # Delete all of Mary's many lists except those in projects
    mary_lists = SpeciesList.where(user: mary)
    before_count = mary_lists.count
    proj_lists = mary_lists.select { |list| list.projects.count.positive? }
    proj_count = proj_lists.count
    assert_operator(proj_count, ">", 0)
    assert_operator(before_count, ">", proj_count)
    mary.delete_private_species_lists
    after_count = SpeciesList.where(user: mary).count
    assert_operator(before_count, ">", after_count)
    assert_equal(proj_count, after_count)
  end

  def test_delete_unattached_collection_numbers
    num = collection_numbers(:minimal_unknown_coll_num)
    assert_equal(1, num.observations.count)
    obs = num.observations.first
    assert_users_equal(mary, obs.user)

    # Not unattached at this point.
    mary.delete_unattached_collection_numbers
    assert_not_nil(CollectionNumber.find(num.id))

    # This should orphan but not delete the collection number.
    obs.destroy
    assert_not_nil(CollectionNumber.find(num.id))

    # Should get deleted now.
    mary.delete_unattached_collection_numbers
    assert_empty(CollectionNumber.where(id: num.id))
  end

  def test_delete_unattached_herbarium_records
    rec = herbarium_records(:interesting_unknown)
    assert_users_equal(rolf, rec.user)
    assert_equal(2, rec.observations.count)
    obs1 = observations(:minimal_unknown_obs)
    obs2 = observations(:detailed_unknown_obs)
    assert_users_equal(mary, obs1.user)
    assert(obs1.herbarium_records.include?(rec))
    assert(obs2.herbarium_records.include?(rec))

    # Used by two observations at first.
    rolf.delete_unattached_herbarium_records
    assert_not_nil(HerbariumRecord.find(rec.id))

    # Still used by one observation.
    obs1.destroy
    rolf.reload.delete_unattached_herbarium_records
    assert_not_nil(HerbariumRecord.find(rec.id))

    # Now unattached and deletable.
    obs2.destroy
    rolf.reload.delete_unattached_herbarium_records
    assert_raises(ActiveRecord::RecordNotFound) \
      { HerbariumRecord.find(rec.id) }
  end

  def test_delete_unattached_images
    # This is supposedly unused by anything.
    img1 = images(:convex_image)
    assert_users_equal(rolf, img1.user)

    # This is used by something.
    img2 = images(:agaricus_campestris_image)
    assert_users_equal(rolf, img2.user)

    rolf.delete_unattached_images
    assert_raises(ActiveRecord::RecordNotFound) { Image.find(img1.id) }
    assert_not_nil(Image.find(img2.id))
  end

  def test_no_references_left
    junk = users(:junk)
    spam = users(:spammer)
    zero = users(:zero_user)

    assert_false(rolf.no_references_left?)
    assert_false(junk.no_references_left?)
    assert_false(spam.no_references_left?)
    assert_true(zero.no_references_left?)

    # Interests don't count.
    assert_operator(0, "<", junk.interests.count)
    assert_operator(0, "<", junk.namings.count)
    junk.namings.first.destroy
    assert_true(junk.reload.no_references_left?)

    assert_operator(0, "<", spam.publications.count)
    spam.publications.first.destroy
    assert_true(spam.reload.no_references_left?)
  end
end
