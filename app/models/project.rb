class Project < ActiveRecord::Base
  belongs_to :user
  belongs_to :user_group
  belongs_to :admin_group, :class_name => "UserGroup", :foreign_key => "admin_group_id"
  has_many :draft_names
  
  def is_member?(user)
    user and (self.user_group.users.member?(user) or (user.id == 0))
  end
  
  def is_admin?(user)
    user and (self.admin_group.users.member?(user) or (user.id == 0))
  end

  protected

  def validation # :nodoc:
    if !self.user
      errors.add(:user, :validate_project_user_missing.t)
    end
    if !self.admin_group
      errors.add(:admin_group, :validate_project_admin_group_missing.t)
    end
    if !self.user_group
      errors.add(:user_group, :validate_project_user_group_missing.t)
    end

    if self.title.to_s.blank?
      errors.add(:title, :validate_project_title_missing.t)
    elsif self.title.length > 100
      errors.add(:title, :validate_project_title_too_long.t)
    end
  end
end
