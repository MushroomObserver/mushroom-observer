# frozen_string_literal: true

# Form object for adding a user to a user group
# Encapsulates validation and business logic for the admin operation
class FormObject::AddUserToGroup
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :user_name, :string
  attribute :group_name, :string

  # Override model_name to control form field namespacing
  # This makes field names like add_user_to_group[user_name]
  # instead of form_object_add_user_to_group[user_name]
  def self.model_name
    ActiveModel::Name.new(self, nil, "AddUserToGroup")
  end

  validates :user_name, :group_name, presence: true
  validate :user_exists
  validate :group_exists
  validate :user_not_already_in_group

  attr_reader :user, :group

  def save
    return false unless valid?

    group.users << user
    true
  rescue StandardError => e
    errors.add(:base, "An error occurred: #{e.message}")
    false
  end

  private

  def user_exists
    @user = User.find_by(login: user_name)
    errors.add(:user_name, :runtime_no_match.t) unless @user
  end

  def group_exists
    @group = UserGroup.find_by(name: group_name)
    errors.add(:group_name, :runtime_no_match.t) unless @group
  end

  def user_not_already_in_group
    return unless @user && @group

    return unless @group.users.include?(@user)

    errors.add(:base,
               :add_user_to_group_already.t(user: @user.login,
                                            group: @group.name))
  end
end
