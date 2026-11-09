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

    connect(session: { user_id: rolf.id, auth: rolf.auth_code })

    assert_equal(connection.current_user, rolf)
  end

  # Rotating a user's auth_code closes connections carrying the
  # previous one, and a session predating the binding carries none.
  def test_session_auth_code_must_match
    rolf = users(:rolf)

    assert_reject_connection do
      connect(session: { user_id: rolf.id, auth: "stale-code" })
    end
    assert_reject_connection { connect(session: { user_id: rolf.id }) }
  end

  def test_session_user_must_be_verified_and_unblocked
    unverified = users(:unverified)

    assert_reject_connection do
      connect(session: { user_id: unverified.id,
                         auth: unverified.auth_code })
    end
  end

  def test_cookie_user_must_be_verified_and_unblocked
    unverified = users(:unverified)
    cookies["mo_user"] = "#{unverified.id} #{unverified.auth_code}"

    assert_reject_connection { connect }
  end

  def test_rejects_connection
    # Use `assert_reject_connection` matcher to verify that
    # connection is rejected
    assert_reject_connection { connect }
  end
end
