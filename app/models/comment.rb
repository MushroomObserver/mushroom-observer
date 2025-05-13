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
#  1. Add to +ALL_TYPES+ Array in this file and AbstractModel.NAME_TO_TYPE
#  2. Add +has_many+ relationships to the model:
#
#       has_many :comments,  :as => :target, :dependent => :destroy
#       has_many :interests, :as => :target, :dependent => :destroy
#
#  3. Add interest "eyes" to the header section of the show_object view:
#
#       add_interest_icons(@user, @target)
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
#  created_at("yyyy-mm-dd", "yyyy-mm-dd")
#  updated_at("yyyy-mm-dd", "yyyy-mm-dd")
#  by_user(user)
#  for_user(user)
#  target(target)
#  summary_has(phrase)
#  content_has(phrase)
#  pattern(phrase)
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

  belongs_to :user
  belongs_to :target, polymorphic: true

  # Maintain this Array of all models (Classes) which take comments.
  ALL_TYPES = [
    Location, LocationDescription, Name, NameDescription,
    Observation, Project, SpeciesList
  ].freeze

  # Returns Array of all valid +target_type+ values (Symbols).
  ALL_TYPE_TAGS = ALL_TYPES.map { |type| type.to_s.underscore.to_sym }.freeze

  # Allow explicit joining for all polymorphic associations,
  # e.g. `Comment.joins(:location).where(target_id: 29513)`,
  # by restating the association below with a scope.
  # https://veelenga.github.io/joining-polymorphic-associations/
  ALL_TYPE_TAGS.each do |model|
    belongs_to model, lambda {
      where(comments: { target_type: model.to_s.camelize })
    }, foreign_key: "target_id", inverse_of: :comments
  end

  # Default broadcasting "later" (with solid_queue and ActiveJob)
  # NOTE: create/update doesn't work locally after first job, but
  # turbo-rails gem v >= 2.0.14 should fix this.
  # https://github.com/hotwired/turbo-rails/pull/710 -
  # broadcasts_to(->(comment) { [comment.target, :comments] },
  #               inserts_by: :prepend, partial: "comments/comment",
  #               locals: { controls: true },
  #               target: "comments")

  # Broadcast "now" (without solid_queue and ActiveJob)
  # (broadcasts_to calls broadcast_prepend_later_to and _replace_later)
  after_create_commit lambda { |comment|
    broadcast_prepend_to(
      [comment.target, :comments],
      partial: "comments/comment", locals: { controls: true }
    )
  }
  after_update_commit lambda { |comment|
    broadcast_replace_to(
      [comment.target, :comments],
      partial: "comments/comment", locals: { controls: true }
    )
  }
  after_destroy_commit lambda { |comment|
    broadcast_remove_to(comment.target, :comments)
  }

  after_create :notify_users
  after_create :oil_and_water

  scope :order_by_default,
        -> { order_by(::Query::Comments.default_order) }

  # This scope starts with a `where`, and chains subsequent `where` clauses
  # with `or`. So, rather than separately assembling `target_ids`, that would
  # execute multiple db queries:
  #
  #   target_ids = []
  #   ALL_TYPES.each do |model|
  #     target_ids |= model.where(user: user).pluck(:id)
  #   end
  #   where(target_id: target_ids)
  #
  # ...this `reduce` iteration only generates one very complex sql statement,
  # with inner selects, and it's faster because AR can figure out that all the
  # chained selects constitute one giant SELECT, and SQL is faster than Ruby.
  #
  # Basically it's iterating over all the types doing this:
  #   where(target_type: :location,
  #         target_id: Location.where(user: user)).
  #   or(where(target_type: :name,
  #            target_id: Name.where(user: user))) etc.
  scope :for_user, lambda { |user|
    ALL_TYPES.reduce(nil) do |scope, model|
      scope2 = where(target_type: model.name.underscore.to_sym,
                     target_id: model.where(user: user))
      scope ? scope.or(scope2) : scope2
    end
  }
  # Pass either { type:, id: } or a commentable model instance.
  # Scope makes sure instance exists.
  scope :target, lambda { |target|
    if target.is_a?(Hash) && target[:type] && target[:id]
      type = target[:type]
      return none unless (model = Comment.safe_model_from_name(type))

      target = model.safe_find(target[:id])
    elsif target.is_a?(AbstractModel)
      type = target.class.name
      return none unless Comment.safe_model_from_name(type)
    end

    where(target:)
  }
  scope :types,
        ->(types) { where(target_type: types) }
  scope :summary_has,
        ->(phrase) { search_columns(Comment[:summary], phrase) }
  scope :content_has,
        ->(phrase) { search_columns(Comment[:comment], phrase) }

  scope :pattern, lambda { |phrase|
    cols = (Comment[:summary] + Comment[:comment].coalesce(""))
    search_columns(cols, phrase)
  }

  scope :search_content, lambda { |phrase|
    # `or` is 10-20% faster than concatenating the columns
    search_columns(Comment[:comment], phrase).
      or(Comment.search_columns(Comment[:summary], phrase)).distinct
  }

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
    return unless target.respond_to?(:log)

    target.log(:log_comment_added, summary: summary, touch: true)
  end

  # Log update of comment on object's RSS log if it can.
  def log_update(target = self.target)
    return unless target.respond_to?(:log)

    target.log(:log_comment_updated, summary: summary, touch: false)
  end

  # Log destruction of comment on object's RSS log if it can.
  def log_destroy(target = self.target)
    return unless target.respond_to?(:log)

    target.log(:log_comment_destroyed, summary: summary, touch: false)
  end

  # Return model if params[:type] is the name of a commentable model
  # Else nil
  def self.safe_model_from_name(name)
    ALL_TYPES.find { |m| m.name == name.to_s }
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
