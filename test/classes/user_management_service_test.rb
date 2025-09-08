# frozen_string_literal: true

require("test_helper")

class UserManagementServiceTest < UnitTestCase
  def test_list
    log_contents = with_captured_logger do
      service = UserManagementService.new
      service.list_users
    end
    assert_match(/#{User.first.login}/, log_contents)
  end

  def test_list_no_users
    User.delete_all

    log_contents = with_captured_logger do
      service = UserManagementService.new
      service.list_users
    end
    assert_match(/#{:user_list_no_users.t}/, log_contents)
  end

  def test_verified_login?
    user = users(:mary)
    fake_input = StringIO.new("#{user.login}\n")
    original_stdin = $stdin
    begin
      $stdin = fake_input

      log_contents = with_captured_logger do
        service = UserManagementService.new
        assert(service.verify_user?)
      end
      assert_match(/is already verified/, log_contents)
      user.reload
      assert(user.verified)
    ensure
      $stdin = original_stdin
    end
  end

  def test_verified_with_bad_login?
    bad_login = "bad-login"
    fake_input = StringIO.new("#{bad_login}\n")
    original_stdin = $stdin
    begin
      $stdin = fake_input

      log_contents = with_captured_logger do
        service = UserManagementService.new
        assert_not(service.verify_user?)
      end
      msg = :user_verify_login_missing.t(login: bad_login).unescape_html
      assert_match(/#{msg}/, log_contents)
    ensure
      $stdin = original_stdin
    end
  end

  def test_verified_email?
    user = users(:mary)
    fake_input = StringIO.new("#{user.email}\n")
    original_stdin = $stdin
    begin
      $stdin = fake_input

      log_contents = with_captured_logger do
        service = UserManagementService.new
        assert(service.verify_user?)
      end
      assert_match(/is already verified/, log_contents)
      user.reload
      assert(user.verified)
    ensure
      $stdin = original_stdin
    end
  end

  def test_verified_bad_email?
    bad_email = "bad@email.com"
    fake_input = StringIO.new("#{bad_email}\n")
    original_stdin = $stdin
    begin
      $stdin = fake_input

      log_contents = with_captured_logger do
        service = UserManagementService.new
        assert_not(service.verify_user?)
      end
      msg = :user_verify_email_missing.t(email: bad_email).unescape_html
      assert_match(/#{msg}/, log_contents)
    ensure
      $stdin = original_stdin
    end
  end

  def test_unverified_login?
    user = users(:unverified)
    fake_input = StringIO.new("#{user.login}\n")
    assert_nil(user.verified)
    original_stdin = $stdin
    begin
      $stdin = fake_input

      log_contents = with_captured_logger do
        service = UserManagementService.new
        assert(service.verify_user?)
      end
      msg = :user_verify_verified.t(login: user.login, timestamp: "").
            unescape_html
      assert_match(/#{msg}/, log_contents)
      user.reload
      assert(user.verified)
    ensure
      $stdin = original_stdin
    end
  end

  def test_mixed_same_email_quit
    users(:foray_recorder)
    user = users(:foray_recorder)
    fake_input = StringIO.new("#{user.email}\nq\n")
    original_stdin = $stdin
    begin
      $stdin = fake_input

      log_contents = with_captured_logger do
        service = UserManagementService.new
        assert_not(service.verify_user?)
      end
      assert_match(/Verified/, log_contents)
      assert_match(/Not verified/, log_contents)
      assert_match(/Operation cancelled/, log_contents)
    ensure
      $stdin = original_stdin
    end
  end

  def test_mixed_same_email_verify_verified
    user1 = users(:foray_recorder)
    users(:unverified_recorder)
    fake_input = StringIO.new("#{user1.email}\n1\n")
    original_stdin = $stdin
    begin
      $stdin = fake_input

      log_contents = with_captured_logger do
        service = UserManagementService.new
        assert(service.verify_user?)
      end
      assert_match(/Verified/, log_contents)
      assert_match(/Not verified/, log_contents)
      assert_match(/is already verified/, log_contents)
    ensure
      $stdin = original_stdin
    end
  end

  def test_mixed_same_email_verify_unverified
    user1 = users(:foray_recorder)
    user2 = users(:unverified_recorder)
    fake_input = StringIO.new("#{user1.email}\n2\n")
    original_stdin = $stdin
    begin
      $stdin = fake_input

      log_contents = with_captured_logger do
        service = UserManagementService.new
        assert(service.verify_user?)
      end
      assert_match(/Verified/, log_contents)
      assert_match(/Not verified/, log_contents)
      msg = :user_verify_verified.t(login: user2.login,
                                    timestamp: "").unescape_html
      assert_match(/#{msg}/, log_contents)
    ensure
      $stdin = original_stdin
    end
  end

  def test_mixed_same_email_verify_all
    user1 = users(:foray_recorder)
    user2 = users(:unverified_recorder)
    fake_input = StringIO.new("#{user1.email}\n3\n")
    original_stdin = $stdin
    begin
      $stdin = fake_input

      log_contents = with_captured_logger do
        service = UserManagementService.new
        assert(service.verify_user?)
      end
      assert_match(/Verified/, log_contents)
      assert_match(/Not verified/, log_contents)
      assert_match(/Verified: #{user2.login}/, log_contents)
      assert_match(/Successfully verified/, log_contents)
    ensure
      $stdin = original_stdin
    end
  end

  def test_mixed_same_email_verify_invalid
    user1 = users(:foray_recorder)
    users(:unverified_recorder)
    fake_input = StringIO.new("#{user1.email}\nx\nq\n")
    original_stdin = $stdin
    begin
      $stdin = fake_input

      log_contents = with_captured_logger do
        service = UserManagementService.new
        assert_not(service.verify_user?)
      end
      assert_match(/Verified/, log_contents)
      assert_match(/Not verified/, log_contents)
      assert_match(/Invalid choice/, log_contents)
    ensure
      $stdin = original_stdin
    end
  end

  def test_create_user
    fake_input = StringIO.new("foobar\nFoo Bar\nfoo@bar.com\n" \
                              "password\npassword\n")
    fake_input.define_singleton_method(:noecho) do |&block|
      block.call(self)
    end
    original_stdin = $stdin
    begin
      $stdin = fake_input

      log_contents = with_captured_logger do
        service = UserManagementService.new
        assert(service.create_user?)
      end
      assert_match(/#{:user_add_success.t(login: "foobar").unescape_html}/,
                   log_contents)
    ensure
      $stdin = original_stdin
    end
  end

  def test_create_user_password_mismatch
    fake_input = StringIO.new("foobar\nFoo Bar\nfoo@bar.com\n" \
                              "password\npasswd\n")
    fake_input.define_singleton_method(:noecho) do |&block|
      block.call(self)
    end
    original_stdin = $stdin
    begin
      $stdin = fake_input

      log_contents = with_captured_logger do
        service = UserManagementService.new
        assert_not(service.create_user?)
      end
      assert_match(/Passwords do not match/, log_contents)
    ensure
      $stdin = original_stdin
    end
  end

  def test_create_user_bad_email
    fake_input = StringIO.new("foobar\nFoo Bar\nbad_email\n" \
                              "password\npasswd\n")
    fake_input.define_singleton_method(:noecho) do |&block|
      block.call(self)
    end
    original_stdin = $stdin
    begin
      $stdin = fake_input

      log_contents = with_captured_logger do
        service = UserManagementService.new
        assert_not(service.create_user?)
      end
      assert_match(/#{:user_add_email_invalid.t}/, log_contents)
    ensure
      $stdin = original_stdin
    end
  end

  def test_create_user_save_failure
    username = "A" * 100
    fake_input = StringIO.new(
      "#{username}\n#{username}\n#{username}@#{username}.com\n" \
      "#{username}\n#{username}\n"
    )
    fake_input.define_singleton_method(:noecho) do |&block|
      block.call(self)
    end
    original_stdin = $stdin
    begin
      $stdin = fake_input

      log_contents = with_captured_logger do
        service = UserManagementService.new
        assert_not(service.create_user?)
      end
      assert_match(/Login name must be 3 to 40 characters long/, log_contents)
    ensure
      $stdin = original_stdin
    end
  end
end
