# frozen_string_literal: true

require("test_helper")

class ProjectAliasTest < ActiveSupport::TestCase
  def test_valid_user_aliases
    pa = ProjectAlias.find_by(target_type: "User")
    assert_instance_of(User, pa.target)
  end

  def test_valid_location_aliases
    pa = ProjectAlias.find_by(target_type: "Location")
    assert_instance_of(Location, pa.target)
  end

  # verify_target returns an unresolved [tag, args] pair (or nil) --
  # the controller resolves it when flashing (#4901).
  def test_verify_target_already_has_target_id
    pa = ProjectAlias.find_by(target_type: "User")

    assert_nil(pa.verify_target("whatever"))
  end

  def test_verify_target_finds_user_by_login
    user = users(:rolf)
    pa = ProjectAlias.new(target_type: "User", project: projects(:eol_project))

    assert_nil(pa.verify_target(user.login))
    assert_equal(user, pa.target)
  end

  def test_verify_target_no_match
    pa = ProjectAlias.new(target_type: "User", project: projects(:eol_project))

    result = pa.verify_target("no_such_login")

    assert_equal([:project_alias_no_match,
                  { target_type: "User", term: "no_such_login" }],
                 result)
  end
end
