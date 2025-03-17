# frozen_string_literal: true

require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  def test_connects_with_cookies
    rolf = users(:rolf)
    cookies["mo_user"] = "#{rolf.id} #{rolf.auth_code}"

    connect

    assert_equal(connection.current_user, rolf)
  end

  def test_rejects_connection
    # Use `assert_reject_connection` matcher to verify that
    # connection is rejected
    assert_reject_connection { connect }
  end
end
