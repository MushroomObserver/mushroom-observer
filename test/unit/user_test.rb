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

    u.password = u.password_confirmation = ""
    assert !u.save
    assert u.errors.invalid?('password')

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

    assert(group1 = UserGroup.all_users)
    assert(group2 = UserGroup.one_user(user))
    assert_user_list_equal(all + [user], group1.users)
    assert_user_list_equal([user], group2.users)

    UserGroup.destroy_user(user)
    user.destroy
    group1.reload
    group2.reload # not destroyed, just empty
    assert_user_list_equal(all, group1.users)
    assert_user_list_equal([], group2.users)
  end
end
