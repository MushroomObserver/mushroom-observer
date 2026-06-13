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

  # Show / index pages render the project banner plus the alias
  # target. Reuse `Project.banner_includes_tree` so the banner
  # eager-loads stay in one place.
  def self.show_includes_tree
    [{ project: Project.banner_includes_tree }, :target]
  end

  def self.index_includes_tree
    show_includes_tree
  end

  # `.strict_loading` on the read scopes (not on the model itself)
  # surfaces N+1s on every show/index path that fetches via these
  # scopes, while leaving plain fixture lookups in tests untouched.
  scope :show_includes, -> { strict_loading.includes(show_includes_tree) }
  scope :index_includes, -> { strict_loading.includes(index_includes_tree) }

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
