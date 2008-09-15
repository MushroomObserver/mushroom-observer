class UserGroup < ActiveRecord::Base
  has_and_belongs_to_many :user_groups
end
