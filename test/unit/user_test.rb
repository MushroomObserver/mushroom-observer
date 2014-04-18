# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class UserTest < UnitTestCase

  def test_auth
    assert_equal @rolf, User.authenticate("rolf", "testpassword")
    assert_nil   User.authenticate("nonrolf", "testpassword")
  end

  def test_password_change
    @mary.change_password("marypasswd")
    assert_equal @mary, User.authenticate("mary", "marypasswd")
    assert_nil   User.authenticate("mary", "longtest")
    @mary.change_password("longtest")
    assert_equal @mary, User.authenticate("mary", "longtest")
    assert_nil   User.authenticate("mary", "marypasswd")
  end

  def test_disallowed_passwords
    u = User.new
    u.login = "nonbob"
    u.email = "nonbob@collectivesource.com"
    u.theme = "NULL"
    u.notes = ""
    u.mailing_address = ""

    u.password = u.password_confirmation = "tiny"
    assert !u.save
    assert u.errors.invalid?('password')

    u.password = u.password_confirmation = "hugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehuge"
    assert !u.save
    assert u.errors.invalid?('password')

    # This is allowed now so that API can create users without a password chosen yet.
    # u.password = u.password_confirmation = ""
    # assert !u.save
    # assert u.errors.invalid?('password')

    u.password = u.password_confirmation = "bobs_secure_password"
    assert u.save
    assert u.errors.empty?
  end

  def test_bad_logins
    u = User.new
    u.password = u.password_confirmation = "bobs_secure_password"
    u.email = "bob@collectivesource.com"
    u.theme = "NULL"
    u.notes = ""
    u.mailing_address = ""

    u.login = "x"
    assert !u.save
    assert u.errors.invalid?('login')

    u.login = "hugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhug"
    assert !u.save
    assert u.errors.invalid?('login')

    u.login = ""
    assert !u.save
    assert u.errors.invalid?('login')

    u.login = "okbob"
    assert u.save
    assert u.errors.empty?
  end

  def test_collision
    u = User.new
    u.login = "rolf"
    u.email = "rolf@collectivesource.com"
    u.theme = "NULL"
    u.notes = ""
    u.mailing_address = ""
    u.password = u.password_confirmation = "rolfs_secure_password"
    assert !u.save
  end

  def test_create
    u = User.new
    u.login = "nonexistingbob"
    u.email = "nonexistingbob@collectivesource.com"
    u.theme = "NULL"
    u.notes = ""
    u.mailing_address = ""
    u.password = u.password_confirmation = "bobs_secure_password"
    u.email = "nonexistingbob@collectivesource.com"
    assert u.save
  end

  def test_sha1
    u = User.new
    u.login = "nonexistingbob"
    u.password = u.password_confirmation = "bobs_secure_password"
    u.email = "nonexistingbob@collectivesource.com"
    u.theme = "NULL"
    u.notes = ""
    u.mailing_address = ""
    assert u.save
    assert_equal '74996ba5c4aa1d583563078d8671fef076e2b466', u.password
  end

  def test_meta_groups
    all = User.all
    group1 = UserGroup.all_users
    assert_user_list_equal(all, group1.users)

    user = User.create!(
      :password              => 'blah!',
      :password_confirmation => 'blah!',
      :login                 => 'bobby',
      :email                 => 'bob@bigboy.com',
      :theme                 => nil,
      :notes                 => '',
      :mailing_address       => ''
    )
    UserGroup.create_user(user)

    group1.reload
    group2 = UserGroup.one_user(user)
    assert_user_list_equal(all + [user], group1.users)
    assert_user_list_equal([user], group2.users)

    UserGroup.destroy_user(user)
    user.destroy
    group1.reload
    group2.reload # not destroyed, just empty
    assert_user_list_equal(all, group1.users)
    assert_user_list_equal([], group2.users)
  end

  # Bug seen in the wild: myxomop created a username which was just under 80
  # characters long, but which had a few accents, so it was > 80 *bytes* long,
  # and it truncated right in the middle of a utf-8 sequence.  Broke the front
  # page of the site for several minutes.
  def test_myxomops_debacle
    name = "Herbario Forestal Nacional Martín Cárdenas de la Universidad Mayor de San Simón"
    name2 = "Herbario Forestal Nacional Martín Cárdenas de la Universidad Mayor de San Sim."
    @mary.name = name
    assert(!@mary.save)
    @mary.name = name2
    assert(@mary.save)
    @mary.reload
    assert_equal(name2, @mary.name)
  end

  def test_all_editable_species_lists
    proj = projects(:bolete_project)
    spl1  = species_lists(:first_species_list)
    spl2  = species_lists(:another_species_list)
    spl3  = species_lists(:unknown_species_list)
    assert_obj_list_equal([spl1, spl2], @rolf.species_lists.sort_by(&:id))
    assert_obj_list_equal([spl3], @mary.species_lists)
    assert_obj_list_equal([], @dick.species_lists)
    assert_obj_list_equal([@dick], proj.user_group.users)
    assert_obj_list_equal([spl3], proj.species_lists)

    assert_obj_list_equal([spl1, spl2], @rolf.all_editable_species_lists.sort_by(&:id))
    assert_obj_list_equal([spl3], @mary.all_editable_species_lists)
    assert_obj_list_equal([spl3], @dick.all_editable_species_lists)

    proj.add_species_list(spl1)
    @dick.reload
    assert_obj_list_equal([spl1, spl3], @dick.all_editable_species_lists.sort_by(&:id))

    proj.user_group.users.push(@rolf, @mary)
    proj.user_group.users.delete(@dick)
    @rolf.reload
    @mary.reload
    @dick.reload
    assert_obj_list_equal([spl1, spl2, spl3], @rolf.all_editable_species_lists.sort_by(&:id))
    assert_obj_list_equal([spl1, spl3], @mary.all_editable_species_lists.sort_by(&:id))
    assert_obj_list_equal([], @dick.all_editable_species_lists)
  end

  def test_preferred_herbarium_name
    assert_equal(@rolf.preferred_herbarium_name, herbaria(:nybg).name)
    assert_equal(@mary.preferred_herbarium_name, :user_personal_herbarium.t(:name => @mary.unique_text_name))
  end

  def test_remove_image
    user = users(:rolf)
    image = user.image
    assert(image)
    user.remove_image(image)
    user.reload
    assert_nil(user.image)
  end

# For some reason this is breaking test_meta_groups, and I can't figure out why.
#   def test_erase_user
#     user = users(:spammer)
#     user_id = user.id
#     group_id = UserGroup.one_user(user_id).id
#     pub_id = user.publications[0].id
#     User.erase_user(user_id)
#     assert_raise(ActiveRecord::RecordNotFound) { User.find(user_id) }
#     assert_raise(ActiveRecord::RecordNotFound) { UserGroup.find(group_id) }
#     assert(!UserGroup.all_users.user_ids.include?(user_id))
#     assert_raise(ActiveRecord::RecordNotFound) { Publication.find(pub_id) }
#   end

  def test_erase_user_with_comment_and_name_descriptions
    user = users(:dick)
    num_comments = Comment.count
    assert_equal(1, user.comments.length)
    comment_id = user.comments.first.id
    num_name_descriptions = NameDescription.count
    assert(user.name_descriptions.length > 1)
    sample_name_description_id = user.name_descriptions.first.id
    User.erase_user(user.id)
    assert_equal(num_comments - 1, Comment.count)
    assert_raise(ActiveRecord::RecordNotFound) { Comment.find(comment_id) }
    assert_equal(num_name_descriptions, NameDescription.count)
    desc = NameDescription.find(sample_name_description_id)
    assert_equal(0, desc.user_id)
  end

  def test_erase_user_with_observation
    user = users(:katrina)
    num_observations = Observation.count
    num_namings = Naming.count
    num_votes = Vote.count
    num_images = Image.count
    num_comments = Comment.count
    num_publications = Publication.count

    # Find Katrina's one observation.
    assert_equal(1, user.observations.length)
    observation = user.observations.first
    observation_id = observation.id

    # Attach her image to the observation.
    image = user.images.first
    image.observations << observation
    image.save
    image_id = image.id
    assert_equal(1, image.observations.length)
    assert_equal(observation_id, image.observations.first.id)

    # Move some other user's comment over to make sure they get deleted, too.
    comment = users(:rolf).comments.first
    comment.target_id = observation.id
    comment.save
    comment_id = comment.id

    # Fixtures have one vote for this observation, but the naming the vote refers to applies to another observation!
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
    assert_equal(num_observations - 1, Observation.count)
    assert_equal(num_namings - 1, Naming.count)
    assert_equal(num_votes - 1, Vote.count)
    assert_equal(num_images - 1, Image.count)
    assert_equal(num_comments - 1, Comment.count)
    assert_equal(num_publications - 1, Publication.count)
    assert_raise(ActiveRecord::RecordNotFound) { Observation.find(observation_id) }
    assert_raise(ActiveRecord::RecordNotFound) { Naming.find(naming_id) }
    assert_raise(ActiveRecord::RecordNotFound) { Vote.find(vote_id) }
    assert_raise(ActiveRecord::RecordNotFound) { Image.find(image_id) }
    assert_raise(ActiveRecord::RecordNotFound) { Comment.find(comment_id) }
    assert_raise(ActiveRecord::RecordNotFound) { Publication.find(publication_id) }
  end
end
