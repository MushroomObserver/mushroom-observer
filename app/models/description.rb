# frozen_string_literal: true

#
#  = Base Class for Models with Authored Descriptions
#
#  This class provides the common functionality between NameDescription and
#  Location::Description.
#
#  == Class Methods
#
#  None.
#
#  == Instance Methods
#
#  ==== Title formats
#  text_name::                  Description of Agaricus from Source
#  unique_text_name::           Description of Agaricus from Source (123)
#  format_name::                Description of **__Agaricus__** from __Source__
#  unique_format_name::    Description of **__Agaricus__** from __Source__ (123)
#  partial_text_name::          Description from Source
#  unique_partial_text_name::   Description from Source (123)
#  partial_format_name::        Description from __Source__
#  unique_partial_format_name:: Description from __Source__ (123)
#
#  ==== Past Versions
#  versions::             List of past versions.
#  versioned_table_name:: Table used to keep past versions.
#
#  ==== Descriptive Text
#  has_any_notes?::       Are any of the notes fields non-empty?
#  all_notes::            Return all the notes fields via a Hash.
#  all_notes=::           Change all the notes fields via a Hash.
#  note_status::          Return some basic stats on notes fields.
#
#  ==== Source Info
#  source_type::          Category of source, e.g. :public, :project, :user.
#  source_name::          Source identifier (e.g., Project title).
#  source_object::        Return reference to object representing source.
#  belongs_to_project?::  Does this Description belong to a given Project?
#
#  ==== Permissions
#  admins::               User's with admin privileges.
#  writers::              User's with write privileges.
#  readers::              User's with read privileges.
#  admin_ids::            User's with admin privileges, as Array of ids.
#  writer_ids::           User's with write privileges, as Array of ids.
#  reader_ids::           User's with read privileges, as Array of ids.
#  is_admin?::            Does a given User have admin privileges?
#  is_writer?::           Does a given User have write privileges?
#  is_reader?::           Does a given User have read privileges?
#  add_admin::            Give a User or UserGroup admin privileges.
#  add_writer::           Give a User or UserGroup writer privileges.
#  add_reader::           Give a User or UserGroup reader privileges.
#  remove_admin::         Remove a User's or UserGroup's admin privileges.
#  remove_writer::        Remove a User's or UserGroup's writer privileges.
#  remove_reader::        Remove a User's or UserGroup's reader privileges.
#  permitted?::           Does a given User have a given type of permission?
#  group_user_ids::       Get list of user ids from a given permissions table.
#  group_ids::      Get list of user_group ids from a given permissions table.
#  admins_join_table::    Table used to list admin groups.
#  writers_join_table::   Table used to list writer groups.
#  readers_join_table::   Table used to list reader groups.
#  public::               Attribute that is +true+ if all users can read.
#  public_write::         Fake attribute that is +true+ if all users can write.
#
#  ==== Authors and Editors
#  editors::              User's that have edited this Name.
#  authors::              User's that have made "significant" contributions.
#  is_editor?::           Is a given User an editor?
#  is_author?::           Is a given User an author?
#  add_editor::           Make given user an "editor".
#  add_author::           Make given user an "author".
#  remove_author::        Demote given user to "editor".
#  authors_join_table::   Table used to list authors.
#  editors_join_table::   Table used to list editors.
#
#  == Callbacks
#  before_save::          Add User as author/editor before making change.
#  before_destroy::       Subtract authorship/editorship contributions
#                         before destroy.
#
############################################################################

class Description < AbstractModel
  self.abstract_class = true

  # Aliases for location / name.
  def parent
    send(parent_type)
  end

  def parent_id
    send("#{parent_type}_id")
  end

  def parent=(val)
    send("#{parent_type}=", val)
  end

  def parent_id=(val)
    send("#{parent_type}_id=", val)
  end

  # Return parent's class name in lowercase, e.g. 'name' or 'location'.
  def parent_type
    # type_tag.to_s.sub("_description", "")
    # Note parent will need to be module_parent in Rails 6
    # Could use self.class.model_name.singular, probably better!
    self.class.parent.to_s.downcase.sub("::", "_")
    # self.class.model_name.singular
  end

  # Shorthand for "public && public_write"
  def fully_public
    public && public_write
  end

  # Is this group writable by the general public?
  def public_write
    @public_write ||= public_write_was
  end

  # Change state of +public_write+.
  attr_writer :public_write

  # Get the initial state of +public_write+ before modification by form.
  def public_write_was
    writer_group_ids == [UserGroup.all_users.id]
  end

  ##############################################################################
  #
  #  :section: Title/Name Formats
  #
  ##############################################################################

  # Descriptive title including parent name, in plain text.
  def text_name
    put_together_name(:full).t.html_to_ascii
  end

  # Same as +text_name+ but with id tacked on.
  def unique_text_name
    string_with_id(text_name)
  end

  # Descriptive title including parent name, in Textile-formatted text.
  def format_name
    put_together_name(:full)
  end

  # Same as +format_name+ but with id tacked on.
  def unique_format_name
    string_with_id(format_name)
  end

  # Descriptive title without parent name, in plain text.
  def partial_text_name
    build_name(:part).t.html_to_ascii
  end

  # Same as +partial_text_name+ but with id tacked on.
  def unique_partial_text_name
    string_with_id(partial_text_name)
  end

  # Descriptive title without parent name, in Textile-formatted text.
  def partial_format_name
    put_together_name(:part)
  end

  # Same as +partial_format_name+ but with id tacked on.
  def unique_partial_format_name
    string_with_id(partial_format_name)
  end

  # Descriptive subtitle for this description (when it is not necessary to
  # include the title of the parent object), in plain text.  [I'm not sure
  # I like this here.  It might violate MVC a bit too flagrantly... -JPH]
  def put_together_name(full_or_part) # :nodoc:
    tag = :"description_#{full_or_part}_title_#{source_type}"
    user_name = begin
                  user.legal_name
                rescue StandardError
                  "?"
                end
    args = {
      text: source_name,
      user: user_name
    }
    if full_or_part == :full
      args[:object] = parent.format_name
    elsif source_name.present?
      tag = :"#{tag}_with_text"
    end
    tag.l(args)
  end

  ##############################################################################
  #
  #  :section: Descriptions
  #
  ##############################################################################

  # Are any of the descriptive text fields non-empty?
  def has_any_notes?
    result = false
    for field in self.class.all_note_fields
      result = send(field).to_s.match(/\S/)
      break if result
    end
    result
  end

  # Returns a Hash containing all the descriptive text fields.  (See also the
  # counterpart writer-method +all_notes=+.)
  def all_notes
    result = {}
    for field in self.class.all_note_fields
      value = send(field).to_s
      result[field] = value.presence
    end
    result
  end

  # Update all the descriptive text fields via Hash.
  #
  #   hash = name.all_notes
  #   hash[:look_alikes] = "new value"
  #   name.all_notes = hash
  #
  def all_notes=(notes)
    for field in self.class.all_note_fields
      send("#{field}=", notes[field])
    end
  end

  # Find out how much descriptive text has been written for this object.
  # Returns the number of fields filled in, and how many characters total.
  #
  #   num_fields, total_length = name.note_status
  #
  def note_status
    fieldCount = sizeCount = 0
    for (k, v) in all_notes
      if v.present?
        fieldCount += 1
        sizeCount += v.strip_squeeze.length
      end
    end
    [fieldCount, sizeCount]
  end

  ##############################################################################
  #
  #  :section: Sources
  #
  ##############################################################################

  # Note, this is the order they will be listed in show_name.
  ALL_SOURCE_TYPES = [
    :public,    # Public ones created by any user.
    :foreign,   # Foreign "public" description(s) written on another server.
    :source,    # Derived from another source, e.g. another website or book.
    :project,   # Draft created for a project.
    :user       # Created by an individual user.
  ].freeze

  # Return an Array of source type Symbols, e.g. :public, :project, etc.
  def self.all_source_types
    ALL_SOURCE_TYPES
  end

  # Retreive object representing the source (if applicable).  Presently, this
  # only works for Project drafts and User's personal descriptions.  All others
  # return +nil+.
  def source_object
    case source_type
    # (this may eventually be replaced with source_id)
    when :project then project
    when :source then nil # (haven't created "Source" model yet)
    when :user then user
    end
  end

  # Does this Description belong to a given Project?
  def belongs_to_project?(project)
    (source_type == :project) &&
      (project_id == project.id)
  end

  ##############################################################################
  #
  #  :section: Permissions
  #
  ##############################################################################

  # Name of the join table used to keep admin groups.
  def self.admins_join_table
    "#{table_name}_admins".to_sym
  end

  # Name of the join table used to keep admin groups.
  def admins_join_table
    "#{self.class.table_name}_admins".to_sym
  end

  # Name of the join table used to keep writer groups.
  def self.writers_join_table
    "#{table_name}_writers".to_sym
  end

  # Name of the join table used to keep writer groups.
  def writers_join_table
    "#{self.class.table_name}_writers".to_sym
  end

  # Name of the join table used to keep reader groups.
  def self.readers_join_table
    "#{table_name}_readers".to_sym
  end

  # Name of the join table used to keep reader groups.
  def readers_join_table
    "#{self.class.table_name}_readers".to_sym
  end

  # List of all the admins for this description, as ids.
  def admins
    group_users(admins_join_table)
  end

  # List of all the writers for this description, as ids.
  def writers
    group_users(writers_join_table)
  end

  # List of all the readers for this description, as ids.
  def readers
    group_users(readers_join_table)
  end

  # List of all the admins for this description, as ids.
  def admin_ids
    group_user_ids(admins_join_table)
  end

  # List of all the writers for this description, as ids.
  def writer_ids
    group_user_ids(writers_join_table)
  end

  # List of all the readers for this description, as ids.
  def reader_ids
    group_user_ids(readers_join_table)
  end

  # Is a given user an admin for this description?
  def is_admin?(user)
    permitted?(admins_join_table, user)
  end

  # Is a given user an writer for this description?
  def is_writer?(user)
    public_write || permitted?(writers_join_table, user)
  end

  # Is a given user an reader for this description?
  def is_reader?(user)
    public || permitted?(readers_join_table, user)
  end

  # Give a User or UserGroup admin privileges.
  def add_admin(arg)
    chg_permission(admins, arg, :add)
  end

  # Give a User or UserGroup writer privileges.
  def add_writer(arg)
    chg_permission(writers, arg, :add)
  end

  # Give a User or UserGroup reader privileges.
  def add_reader(arg)
    chg_permission(readers, arg, :add)
  end

  # Revoke a User's or UserGroup's admin privileges.
  def remove_admin(arg)
    chg_permission(admins, arg, :remove)
  end

  # Revoke a User's or UserGroup's writer privileges.
  def remove_writer(arg)
    chg_permission(writers, arg, :remove)
  end

  # Revoke a User's or UserGroup's reader privileges.
  def remove_reader(arg)
    chg_permission(readers, arg, :remove)
  end

  # Change a given User's or UserGroup's privileges.
  def chg_permission(groups, arg, mode)
    arg = UserGroup.one_user(arg) if arg.is_a?(User)
    if (mode == :add) &&
       !groups.include?(arg)
      groups.push(arg)
    elsif (mode == :remove) &&
          groups.include?(arg)
      groups.delete(arg)
    end
  end

  # Check if a given user has the given type of permission.
  def permitted?(table, user)
    if user.is_a?(User)
      group_user_ids(table).include?(user.id)
    elsif !user
      group_ids(table).include?(UserGroup.all_users.id)
    elsif user.try(:to_i)&.nonzero?
      group_user_ids(table).include?(user.to_i)
    else
      raise ArgumentError.new("Was expecting User instance, id or nil.")
    end
  end

  # Do minimal query to enumerate the users in a list of groups.  Return as an
  # Array of User instances.  Caches result.
  def group_users(table)
    @group_users ||= {}
    return @group_users[table] if @group_users[table]

    ids = group_user_ids(table)
    ids = ["-1"] if ids.empty?
    id_list = ids.map(&:to_s).join(",")
    @group_users[table] = User.find_by_sql %(
      SELECT * FROM users
      WHERE id IN (#{id_list}))
  end

  # Do minimal query to enumerate the users in a list of groups.  Return as an
  # Array of ids.  Caches result.
  def group_user_ids(table)
    @group_user_ids ||= {}
    @group_user_ids[table] ||= self.class.connection.select_values(%(
      SELECT DISTINCT u.user_id FROM #{table} t, user_groups_users u
      WHERE t.#{type_tag}_id = #{id}
        AND t.user_group_id = u.user_group_id
      ORDER BY u.user_id ASC
    )).map(&:to_i)
  end

  # Do minimal query to enumerate a list of groups.  Return as an Array of ids.
  # Caches result.  (Equivalent to using <tt>association.ids</tt>, I think.)
  def group_ids(table)
    @group_ids ||= {}
    @group_ids[table] ||= self.class.connection.select_values(%(
      SELECT DISTINCT user_group_id FROM #{table}
      WHERE #{type_tag}_id = #{id}
      ORDER BY user_group_id ASC
    )).map(&:to_i)
  end

  ##############################################################################
  #
  #  :section: Authors and Editors
  #
  ##############################################################################

  # Name of the join table used to keep authors.
  def self.authors_join_table
    "#{table_name}_authors".to_sym
  end

  # Name of the join table used to keep authors.
  def authors_join_table
    "#{self.class.table_name}_authors".to_sym
  end

  # Name of the join table used to keep editors.
  def self.editors_join_table
    "#{table_name}_editors".to_sym
  end

  # Name of the join table used to keep editors.
  def editors_join_table
    "#{self.class.table_name}_editors".to_sym
  end

  # Is the given User and author?
  def is_author?(user)
    authors.member?(user)
  end

  # Is the given User and editor?
  def is_editor?(user)
    editors.member?(user)
  end

  # Add a User on as an "author".  Saves User if changed.  Returns nothing.
  def add_author(user)
    unless authors.member?(user)
      authors.push(user)
      SiteData.update_contribution(:add, authors_join_table, user.id)
      if editors.member?(user)
        editors.delete(user)
        SiteData.update_contribution(:del, editors_join_table, user.id)
      end
    end
  end

  # Demote a User to "editor".  Saves User if changed.  Returns nothing.
  def remove_author(user)
    return unless authors.member?(user)

    authors.delete(user)
    SiteData.update_contribution(:del, authors_join_table, user.id)
    if !editors.member?(user) &&
       # Make sure user has actually made at least one change.
       self.class.connection.select_value(%(
         SELECT id FROM #{versioned_table_name}
         WHERE #{type_tag}_id = #{id} AND user_id = #{user.id}
         LIMIT 1
       ))
      editors.push(user)
      SiteData.update_contribution(:add, editors_join_table, user.id)
    end
  end

  # Add a user on as an "editor".
  def add_editor(user)
    if !authors.member?(user) && !editors.member?(user)
      editors.push(user)
      SiteData.update_contribution(:add, editors_join_table, user.id)
    end
  end

  ##############################################################################
  #
  #  :section: Callbacks
  #
  ##############################################################################

  # By default make first user to add any text an author.
  def author_worthy?
    has_any_notes?
  end

  # Callback that updates editors and/or authors after a User makes a change.
  # If the Name has no author and they've made sufficient contributions, they
  # get promoted to author by default.  In all cases make sure the user is
  # added on as an editor.
  before_save :add_author_or_editor
  def add_author_or_editor
    return unless !@save_without_our_callbacks && (user = User.current)

    authors.empty? && author_worthy? ? add_author(user) : add_editor(user)
  end

  # When destroying an object, subtract contributions due to
  # authorship/editorship.
  before_destroy :update_users_and_parent
  def update_users_and_parent
    # Update editors' and authors' contributions.
    authors.each do |user|
      SiteData.update_contribution(:del, authors_join_table, user.id)
    end
    editors.each do |user|
      SiteData.update_contribution(:del, editors_join_table, user.id)
    end

    # Make sure parent doesn't point to a nonexisting object.
    if parent.description_id == id
      parent.description_id = nil
      parent.save_without_our_callbacks
    end
  end
end
