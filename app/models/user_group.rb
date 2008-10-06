class UserGroup < ActiveRecord::Base
  has_and_belongs_to_many :users
  has_one :project
  has_one :admin_project, :class_name => "Project", :foreign_key => "admin_group_id"
end
