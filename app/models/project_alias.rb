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

  # The single-alias show page renders the project banner plus the
  # alias target. Reuse `Project.banner_includes_tree` so the banner
  # eager-loads stay in one place.
  def self.show_includes_tree
    [{ project: Project.banner_includes_tree }, :target]
  end

  # The aliases index table only reads `alias.target` (+ column
  # reads). The controller fetches `@project` separately for the
  # page banner, so the project-banner subtree isn't needed per row.
  def self.index_includes_tree
    [:target]
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

  # Returns nil on success (also setting `target=` as a side effect
  # when a User match is found), or an unresolved [tag, args] pair on
  # failure -- the controller resolves it via `.t` when flashing.
  # Moved the resolution itself out (#4901); its only caller flashes
  # the result, a render-facing concern the model shouldn't own.
  def verify_target(term)
    return nil if target_id

    if target_type == "User"
      user = User.find_by(login: term)
      if user
        self.target = user
        return nil
      end
    end
    [:project_alias_no_match, { target_type: target_type, term: term }]
  end
end
