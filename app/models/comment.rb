# frozen_string_literal: true

#
#  = Comment Model
#
#  A comment is a bit of text a User attaches to an object such as an
#  Observation.  It is polymorphic in the sense that Comment's can be attached
#  to any kind of object, including:
#
#  * Location
#  * Name
#  * Observation
#  * Project
#  * SpeciesList
#
#  == Adding Comments to Model
#
#  It's very easy.  Don't forget to add interests as well, because that will
#  allow the owner/authors of the object commented on to be notified of the
#  new comment.  Just follow these easy steps:
#
#  1. Add to +all_types+ Array in this file.
#  2. Add +has_many+ relationships to the model:
#
#       has_many :comments,  :as => :target, :dependent => :destroy
#       has_many :interests, :as => :target, :dependent => :destroy
#
#  3. Add interest "eyes" to the header section of the show_object view:
#
#       draw_interest_icons(@user, @target)
#
#  4. Add comments_for_object partial at the bottom of the show_object view:
#
#       <%= render(:partial => 'comments/comments_for_object', :locals =>
#             { :target => @target, :controls => true, :limit => nil }) %>
#
#  5. Tell comments/_object shared view how to display the object (used to
#     embed info about object while user is posting/editing a comment):
#
#       when 'YourModel'
#         render(:partial => 'model/model', :target => target)
#
#  6. Tell Query how to do the polymorphic join (optional):
#
#       self.join_conditions => {
#         :comments => {
#           :new_table => :target,
#         }
#       }
#
#  == Attributes
#
#  id::           Locally unique numerical id, starting at 1.
#  created_at::   Date/time it was first created.
#  updated_at::   Date/time it was last updated.
#  user::         User that created it.
#  target::       Object it is attached to.
#  summary::      Summary line (100 chars).
#  comment::      Full text (any length).
#
#  ==== Scopes
#
#  created_on("yyyymmdd")
#  created_after("yyyymmdd")
#  created_before("yyyymmdd")
#  created_between(start, end)
#  updated_on("yyyymmdd")
#  updated_after("yyyymmdd")
#  updated_before("yyyymmdd")
#  updated_between(start, end)
#  by_user(user)
#  for_user(user)
#  for_target(target)
#
#  == Instance Methods
#
#  text_name::              Alias for +summary+ for debugging.
#  target_type_localized::  Translate name of the object type it's attached to.
#
#  ==== Logging
#  log_create::             Log creation on object's log if it can.
#  log_update::             Log update on object's log if it can.
#  log_destroy::            Log destruction on object's log if it can.
#
#  ==== Callbacks
#  notify_users::           Sends notification emails after creation.
#  oil_and_water::          Sends admin email if users start to bicker.
#
#  == Polymorphism
#
#  ActiveRecord accomplishes polymorphism by storing the object _type_ along
#  side the usual object _id_.  So, while there are the convenience wrappers
#  +target+ and +target=+ that hide this detail, underneath there are actually
#  two columns in the database table:
#
#  target_type::  Class name of object (string).
#  target_id::    Id of object (integer).
#
#  Note that most of ActiveRecord's magic continues to work:
#
#    # Find first comment attached to an observation.
#    Comment.find_by_target(observation)
#
#    # Have we changed the object reference (either type or id)?
#    comment.target_changed?
#
class Comment < AbstractModel
  include Callbacks

  belongs_to :target, polymorphic: true
  belongs_to :user

  after_create :notify_users
  after_create :oil_and_water

  scope :by_user,
        ->(user) { where(user: user) }

  # This scope starts with a `where`, and chains subsequent `where` clauses
  # with `or`. So, rather than separately assembling `target_ids`, that would
  # execute multiple db queries:
  #
  #   target_ids = []
  #   all_types.each do |model|
  #     target_ids |= model.where(user: user).pluck(:id)
  #   end
  #   where(target_id: target_ids)
  #
  # ...this `inject` iteration only generates one very complex sql statement,
  # with inner selects, and it's faster because AR can figure out that all the
  # chained selects constitute one giant SELECT, and SQL is faster than Ruby.
  #
  # Basically it's iterating over all the types doing this:
  #   where(target_type: :location,
  #        target_id: Location.where(user: user)).
  #   or(where(target_type: :name,
  #            target_id: Name.where(user: user))) etc.
  scope :for_user,
        lambda { |user|
          all_types.inject(nil) do |scope, model|
            scope2 = where(target_type: model.name.underscore.to_sym,
                           target_id: model.where(user: user))
            scope ? scope.or(scope2) : scope2
          end
        }
  scope :for_target,
        ->(target) { where(target: target) }

  # Returns Array of all models (Classes) which take comments.
  def self.all_types
    [Location, Name, Observation, Project, SpeciesList]
  end

  # Returns Array of all valid +target_type+ values (Symbol's).
  def self.all_type_tags
    [:location, :name, :observation, :project, :species_list]
  end

  # Returns +summary+ for debugging.
  def text_name
    summary.to_s
  end

  # Returns the name of the object type, translated into the local language.
  # Returns '' if fails for any reason.  Equivalent to:
  #
  #   comment.target_type.downcase.to_sym.l
  #
  def target_type_localized
    target_type.downcase.to_sym.l
  rescue StandardError
    ""
  end

  # Log creation of comment on object's RSS log if it can.
  def log_create(target = self.target)
    return unless target&.respond_to?(:log)

    target.log(:log_comment_added, summary: summary, touch: true)
  end

  # Log update of comment on object's RSS log if it can.
  def log_update(target = self.target)
    return unless target&.respond_to?(:log)

    target.log(:log_comment_updated, summary: summary, touch: false)
  end

  # Log destruction of comment on object's RSS log if it can.
  def log_destroy(target = self.target)
    return unless target&.respond_to?(:log)

    target.log(:log_comment_destroyed, summary: summary, touch: false)
  end

  # Return model if params[:type] is the name of a commentable model
  # Else nil
  def self.safe_model_from_name(name)
    all_types.find { |m| m.name == name }
  end

  ############################################################################

  protected

  validate :check_requirements

  def check_requirements # :nodoc:
    check_user
    check_summary
    check_target
  end

  def check_user # :nodoc:
    return if user || User.current

    errors.add(:user, :validate_comment_user_missing.t)
  end

  def check_summary # :nodoc:
    if summary.to_s.blank?
      errors.add(:summary, :validate_comment_summary_missing.t)
    elsif summary.size > 100
      errors.add(:summary, :validate_comment_summary_too_long.t)
    end
  end

  def check_target # :nodoc:
    return unless target_type.to_s.size > 30

    errors.add(:target_type, :validate_comment_object_type_too_long.t)
  end
end
