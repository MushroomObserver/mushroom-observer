# frozen_string_literal: true

class ProjectAlias < AbstractModel
  # Project admins can define a set of "aliases" for users and
  # locations to facilitate data entry in the field. E.g., "NJW" can
  # be made to represent the user `nathan`, or "Walk 10" for the
  # location`USA, Massachusetts, Wellfleet, Marconi Beach`.  The
  # aliases only work in the context of the project (specifically when
  # filling in field slip forms).

  belongs_to :target, polymorphic: true
  belongs_to :project

  validates :name, presence: true
  validates :name, uniqueness: { scope: :project_id }
  validates :target, presence: true

  def target_type=(type)
    self[:target_type] = type.capitalize
  end

  def verify_target(term)
    return nil if target_id

    if target_type == "User"
      user = User.find_by(login: term)
      if user
        self.target = user
        return nil
      end
    end
    :project_alias_no_match.t(target_type:, term:)
  end
end
