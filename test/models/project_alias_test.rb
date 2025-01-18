# frozen_string_literal: true

require "test_helper"

class ProjectAliasTest < ActiveSupport::TestCase
  test "valid user aliases" do
    pa = ProjectAlias.find_by(target_type: "User")
    assert_equal("User", pa.target_type)
    assert_equal(User, pa.target.class)
  end

  test "valid location aliases" do
    pa = ProjectAlias.find_by(target_type: "Location")
    assert_equal(Location, pa.target.class)
  end
end
