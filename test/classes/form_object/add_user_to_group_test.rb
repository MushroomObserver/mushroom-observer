# frozen_string_literal: true

require("test_helper")

class FormObject::AddUserToGroupTest < UnitTestCase
  def test_valid_with_existing_user_and_group
    user = users(:rolf)
    group = user_groups(:all_users)
    # Remove user from group first
    group.users.delete(user)

    form = FormObject::AddUserToGroup.new(
      user_name: user.login,
      group_name: group.name
    )

    assert(form.valid?)
  end

  def test_invalid_without_user_name
    form = FormObject::AddUserToGroup.new(group_name: "test_group")

    assert_not(form.valid?)
    assert(form.errors[:user_name].present?)
  end

  def test_invalid_without_group_name
    form = FormObject::AddUserToGroup.new(user_name: "test_user")

    assert_not(form.valid?)
    assert(form.errors[:group_name].present?)
  end

  def test_invalid_with_nonexistent_user
    group = user_groups(:all_users)

    form = FormObject::AddUserToGroup.new(
      user_name: "nonexistent_user",
      group_name: group.name
    )

    assert_not(form.valid?)
    assert(form.errors[:user_name].present?)
  end

  def test_invalid_with_nonexistent_group
    user = users(:rolf)

    form = FormObject::AddUserToGroup.new(
      user_name: user.login,
      group_name: "nonexistent_group"
    )

    assert_not(form.valid?)
    assert(form.errors[:group_name].present?)
  end

  def test_invalid_when_user_already_in_group
    user = users(:rolf)
    group = user_groups(:all_users)
    # Ensure user is in group
    group.users << user unless group.users.include?(user)

    form = FormObject::AddUserToGroup.new(
      user_name: user.login,
      group_name: group.name
    )

    assert_not(form.valid?)
    assert(form.errors[:base].present?)
  end

  def test_save_adds_user_to_group
    user = users(:rolf)
    group = user_groups(:reviewers)
    # Remove user from group first
    group.users.delete(user)

    form = FormObject::AddUserToGroup.new(
      user_name: user.login,
      group_name: group.name
    )

    assert(form.save)
    assert(group.users.include?(user))
  end

  def test_save_returns_false_when_invalid
    form = FormObject::AddUserToGroup.new(
      user_name: "nonexistent_user",
      group_name: "nonexistent_group"
    )

    assert_not(form.save)
  end

  def test_exposes_user_and_group_after_validation
    user = users(:rolf)
    group = user_groups(:all_users)

    form = FormObject::AddUserToGroup.new(
      user_name: user.login,
      group_name: group.name
    )

    form.valid?

    assert_equal(user, form.user)
    assert_equal(group, form.group)
  end
end
