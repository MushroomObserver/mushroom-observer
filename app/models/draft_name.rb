require_dependency 'acts_as_versioned_extensions'

################################################################################
#
#  An object for holding draft versions of notes for Names.
#
################################################################################

class DraftName < ActiveRecord::Base
  belongs_to :name
  belongs_to :user
  belongs_to :project
  belongs_to :reviewer, :class_name => "User", :foreign_key => "reviewer_id"
  
  acts_as_versioned(:class_name => 'PastDraftName', :table_name => 'past_draft_names')
  non_versioned_columns.push('created')
  ignore_if_changed('modified', 'user_id', 'review_status', 'reviewer_id', 'last_review')
  
  def self.create_from_name(project_id, name_id)
    result = DraftName.new()
    result.project_id = project_id
    result.name_id = name_id
    result.user_id = user_id
  end
  
end
