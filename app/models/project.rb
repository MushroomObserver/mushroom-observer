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
end
