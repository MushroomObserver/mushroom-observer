# frozen_string_literal: true

require("test_helper")

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  def test_connects_with_cookies
    rolf = users(:rolf)
    cookies["mo_user"] = "#{rolf.id} #{rolf.auth_code}"

    connect

    assert_equal(connection.current_user, rolf)
  end

  # A verification-link (or any session-only) login never sets the
  # autologin cookie -- the session must be enough on its own (#4854).
  def test_connects_with_session_and_no_cookie
    rolf = users(:rolf)

    connect(session: { user_id: rolf.id })

    assert_equal(connection.current_user, rolf)
  end

  def test_session_user_must_be_verified_and_unblocked
    unverified = users(:unverified)

    assert_reject_connection { connect(session: { user_id: unverified.id }) }
  end

  def test_rejects_connection
    # Use `assert_reject_connection` matcher to verify that
    # connection is rejected
    assert_reject_connection { connect }
  end
end
