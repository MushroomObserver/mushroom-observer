class Project < ActiveRecord::Base
  belongs_to :user
  belongs_to :user_group
  belongs_to :admin_group, :class_name => "UserGroup", :foreign_key => "admin_group_id"
  has_many :draft_names
  
  def is_member?(user)
    self.user_group.users.member?(user)
  end
  
  def is_admin?(user)
    self.admin_group.users.member?(user)
  end
end
