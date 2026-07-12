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
    assert_empty(u.errors)
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
    assert_empty(u.errors)
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
    obs_count = user.observations.length
    observation = observations(:amateur_obs)
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
    assert_equal(num_observations - obs_count, Observation.count)
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

  def test_admin_id
    assert_equal(User.first.id, User.admin_id)
  end

  def test_ignoring
    user = users(:mary)
    obj = observations(:minimal_unknown_obs)
    assert_false(user.ignoring?(obj))

    Interest.create!(user: user, target: obj, state: false)
    assert_true(user.ignoring?(obj))
  end

  def test_percent_complete
    user = User.new
    assert_equal(0, user.percent_complete)

    user.notes = "Some notes"
    assert_equal(33, user.percent_complete)

    user.location_id = locations(:albion).id
    assert_equal(66, user.percent_complete)

    user.image_id = images(:in_situ_image).id
    assert_equal(100, user.percent_complete)
  end

  def test_old_auth_code
    assert_equal(
      Digest::SHA1.hexdigest("SdFgJwLeRsecretWeRtWeRkTj"),
      User.old_auth_code("secret")
    )
  end

  def test_email_too_long
    user = User.new(
      login: "nonexistingbob",
      email: "#{"a" * 80}@example.com",
      password: "bobs_secure_password",
      password_confirmation: "bobs_secure_password"
    )

    assert_not(user.valid?)
    assert_equal(:validate_user_email_too_long.t, user.errors[:email].first)
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
      theme: "RANDOM",
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

    u.notes_template = "Cap, Collector"
    assert(u.invalid?,
           "Notes template with 'Collector' should be invalid (#4211)")

    u.notes_template = "Cap, Collector's Name"
    assert(u.valid?, "Collector variant headings stay valid")
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

  def test_inactivate_user
    count = Observation.where(user: rolf).count
    assert_operator(0, "<", count)

    rolf.inactivate_user

    # Content is retained (everything on MO is CC-licensed, #4767) -- the
    # old delete_observations would have NULLed these to zero.
    assert_equal(count, Observation.where(user: rolf).count)
    # ...and the account is anonymized (login is the only shown identifier).
    assert_equal("inactive_user_#{rolf.id}", rolf.reload.login)
  end

  # A self-delete on an account with content retains everything, blocks
  # and anonymizes it -- it is NOT erased (#4767).
  def test_disable_and_anonymize_account_retains_content
    obs_count = Observation.where(user_id: rolf.id).count
    key_count = APIKey.where(user_id: rolf.id).count
    assert_operator(0, "<", obs_count)

    rolf.disable_and_anonymize_account
    rolf.reload

    assert(User.exists?(rolf.id), "account with content must be retained")
    assert(rolf.blocked)
    assert_equal("inactive_user_#{rolf.id}", rolf.login)
    assert_equal(obs_count, Observation.where(user_id: rolf.id).count)
    assert_equal(key_count, APIKey.where(user_id: rolf.id).count)
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

  def test_culling_unverified_users
    unverified = users(:unverified)
    msgs = User.cull_unverified_users(dry_run: true)
    assert_equal("Deleted 1 unverified user(s).", msgs.first)
    msgs = User.cull_unverified_users(dry_run: false)
    assert_equal("Deleted 1 unverified user(s).", msgs.first)
    assert_nil(User.find_by(id: unverified.id))
  end

  def test_lookup_unique_text_name
    User.find_each do |user|
      assert_equal(user, User.lookup_unique_text_name(user.unique_text_name))
    end
  end

  def test_nihilist
    user = users(:nihilist_user)
    assert(user.textile_name.include?(user.login))
  end

  def test_user_with_underscore
    user = users(:lone_wolf)
    assert_match(/lookup_user/, user.textile_name.tl)
  end

  def test_top_users_for_herbarium
    # This herbarium has two curators: rolf and roy
    # But only rolf has used it
    nybg_h_top_users = User.top_users_for_herbarium(herbaria(:nybg_herbarium))
    assert_equal(1, nybg_h_top_users.count)
    assert_equal("rolf", nybg_h_top_users[0].login)

    # Dick has not used his herbarium
    dick_h_top_users = User.top_users_for_herbarium(herbaria(:dick_herbarium))
    assert_equal(0, dick_h_top_users.count)

    # Mary's the top user of fundis herbarium
    fundis_h_top_users = User.top_users_for_herbarium(
      herbaria(:fundis_herbarium)
    )
    assert_equal(1, fundis_h_top_users.count)
    assert_equal("mary", fundis_h_top_users[0].login)
    # Now move all rolf's records to this herbarium
    HerbariumRecord.where(user_id: users(:rolf).id).
      update_all(herbarium_id: herbaria(:fundis_herbarium).id)
    fundis_h_top_users = User.top_users_for_herbarium(
      herbaria(:fundis_herbarium)
    )
    assert_equal(2, fundis_h_top_users.count)
    assert_equal("rolf", fundis_h_top_users[0].login)
    assert_equal("mary", fundis_h_top_users[1].login)

    # Thorsten's the top user of fundis herbarium
    field_h_top_users = User.top_users_for_herbarium(herbaria(:field_museum))
    assert_equal(1, field_h_top_users.count)
    assert_equal("thorsten", field_h_top_users[0].login)
    # Now change the attribution of thorsten's herbarium record
    HerbariumRecord.find(herbarium_records(:field_museum_record).id).
      update(user_id: users(:katrina).id)
    field_h_top_users = User.top_users_for_herbarium(herbaria(:field_museum))
    assert_equal(1, field_h_top_users.count)
    assert_equal("katrina", field_h_top_users[0].login)
  end
end
