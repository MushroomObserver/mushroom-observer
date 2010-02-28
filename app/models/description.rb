#
#  = Base Class for Models with Authored Descriptions
#
#  This class provides the common functionality between NameDescription and
#  LocationDescription.
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
#  unique_format_name::         Description of **__Agaricus__** from __Source__ (123)
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
#  merge_descriptions::   Merge descriptive text of two Description's.
#
#  ==== Source Info
#  source_type::          Category of source, e.g. :public, :project, :user.
#  source_name::          Source identifier (e.g., Project title).
#  source_title::         Return String describing the source.
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
#  has_permission?::      Does a given User have a given type of permission?
#  group_user_ids::       Get list of user ids from a given permissions table.
#  group_ids::            Get list of user_group ids from a given permissions table.
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
#  before_destroy::       Subtract authorship/editorship contributions before destroy.
#
############################################################################

class Description < AbstractModel
  self.abstract_class = true

  # Aliases for location / name.
  def parent;        self.send(parent_type);             end
  def parent_id;     self.send("#{parent_type}_id");     end
  def parent=(x);    self.send("#{parent_type}", x);     end
  def parent_id=(x); self.send("#{parent_type}_id=", x); end

  # Return parent's class name in lowercase, e.g. 'name' or 'location'.
  def parent_type
    self.class.name.underscore.sub('_description', '')
  end

  # Is this group writable by the general public?
  def public_write
    @public_write ||= public_write_was
  end

  # Change state of +public_write+.
  def public_write=(x)
    @public_write = x
  end

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
    build_name(:full).t.html_to_ascii
  end

  # Same as +text_name+ but with id tacked on.
  def unique_text_name
    text_name + " (#{id})"
  end

  # Descriptive title including parent name, in Textile-formatted text.
  def format_name
    put_together_name(:full)
  end

  # Same as +format_name+ but with id tacked on.
  def unique_format_name
    format_name + " (#{id})"
  end

  # Descriptive title without parent name, in plain text.
  def partial_text_name
    build_name(:part).t.html_to_ascii
  end

  # Same as +partial_text_name+ but with id tacked on.
  def unique_partial_text_name
    partial_text_name + " (#{id})"
  end

  # Descriptive title without parent name, in Textile-formatted text.
  def partial_format_name
    put_together_name(:part)
  end

  # Same as +partial_format_name+ but with id tacked on.
  def unique_partial_format_name
    partial_format_name + " (#{id})"
  end

  # Descriptive subtitle for this description (when it is not necessary to
  # include the title of the parent object), in plain text.  [I'm not sure
  # I like this here.  It might violate MVC a bit too flagrantly... -JPH]
  def put_together_name(full_or_part) # :nodoc:
    tag = "description_#{full_or_part}_title_#{source_type}".to_sym
    args = { :object => parent.format_name }
    result = case source_type
    when :public
      if source_title.to_s != ''
        args[:summary] = source_title
        tag = "#{tag}_with_summary".to_sym
      end
    when :foreign
      args[:server]  = source_title
    when :project
      args[:project] = source_title
      args[:user]    = user.legal_name
    when :source
      args[:source]  = source_title
    when :user
      args[:user]    = user.legal_name
      if user == User.current
        tag = "#{tag}_yours".to_sym
      end
    end
    return tag.l(args)
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
      result = self.send(field).to_s.match(/\S/)
      break if result
    end
    result
  end

  # Returns a Hash containing all the descriptive text fields.  (See also the
  # counterpart writer-method +all_notes=+.)
  def all_notes
    result = {}
    for field in self.class.all_note_fields
      value = self.send(field).to_s.
                   gsub(/\s+$/, '').sub(/\A\n+/, '').sub(/\n+\Z/, '')
      result[field] = value != '' ? value : nil
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
      self.send("#{field}=", notes[field])
    end
  end

  # Find out how much descriptive text has been written for this object.
  # Returns the number of fields filled in, and how many characters total.
  #
  #   num_fields, total_length = name.note_status
  #
  def note_status
    fieldCount = sizeCount = 0
    for (k, v) in self.all_notes
      if v and v.strip != ''
        fieldCount += 1
        sizeCount += v.strip_squeeze.length
      end
    end
    [fieldCount, sizeCount]
  end

  # Attempt to merge another description into this one, deleting the old one
  # if successful.  It will only do so if there is no conflict on any of the
  # description fields, i.e. one or the other is blank for any given field.
  def merge_descriptions(src)
    dest = self
    src_notes = src.all_notes
    dest_notes = dest.all_notes
    if !self.class.all_note_fields.any? \
         {|f| (src_notes[f].to_s != '') and (dest_notes[f].to_s != '')}
      for f, val in dest_notes
        dest.send("#{f}=", val) if val.to_s != ''
      end
      dest.save if dest.changed?
      src.destroy
      result = true
    else
      result = false
    end
  end

  ################################################################################
  #
  #  :section: Sources
  #
  ################################################################################

  ALL_SOURCE_TYPES = [
    :public,    # Public ones created by any user.
    :foreign,   # Foreign "public" description(s) written on another server.
    :project,   # Draft created for a project.
    :source,    # Derived from another source, e.g. another website or book.
    :user       # Created by an individual user.
  ]

  # Return an Array of source type Symbols, e.g. :public, :project, etc.
  def self.all_source_types
    ALL_SOURCE_TYPES
  end

  # Return a String describing the source if applicable, e.g. Project title,
  # server name, User's name, source's name.  All else return +nil+.
  def source_title
    source_name
  end

    # case source_type
    # when :public  ; self.source_name  # (arbitrary description)
    # when :foreign ; self.source_name  # (server name)
    # when :project ; self.source_name  # (project title)
    # when :source  ; self.source_name  # (free-form)
    # when :user    ; self.source_name  # (user's full name)
    # end

  # Retreive object representing the source (if applicable).  Presently, this
  # only works for Project drafts and User's personal descriptions.  All others
  # return +nil+.
  def source_object
    case source_type
                    # (this may eventually be replaced with source_id)
    when :project ; Project.find_by_title(source_title)
    when :source  ; nil  # (haven't created "Source" model yet)
    when :user    ; user
    else            nil
    end
  end

  # Does this Description belong to a given Project?
  def belongs_to_project?(project)
    (source_type == :project) and
    (source_title == :project.title)
  end

  ##############################################################################
  #
  #  :section: Permissions
  #
  ##############################################################################

  # Name of the join table used to keep admin groups.
  def self.admins_join_table; "#{table_name}_admins".to_sym; end

  # Name of the join table used to keep admin groups.
  def admins_join_table; "#{self.class.table_name}_admins".to_sym; end

  # Name of the join table used to keep writer groups.
  def self.writers_join_table; "#{table_name}_writers".to_sym; end

  # Name of the join table used to keep writer groups.
  def writers_join_table; "#{self.class.table_name}_writers".to_sym; end

  # Name of the join table used to keep reader groups.
  def self.readers_join_table; "#{table_name}_readers".to_sym; end

  # Name of the join table used to keep reader groups.
  def readers_join_table; "#{self.class.table_name}_readers".to_sym; end

  # List of all the admins for this description, as ids.
  def admins; group_users(admins_join_table); end

  # List of all the writers for this description, as ids.
  def writers; group_users(writers_join_table); end

  # List of all the readers for this description, as ids.
  def readers; group_users(readers_join_table); end

  # List of all the admins for this description, as ids.
  def admin_ids; group_user_ids(admins_join_table); end

  # List of all the writers for this description, as ids.
  def writer_ids; group_user_ids(writers_join_table); end

  # List of all the readers for this description, as ids.
  def reader_ids; group_user_ids(readers_join_table); end

  # Is a given user an admin for this description?
  def is_admin?(user); has_permission?(admins_join_table, user); end

  # Is a given user an writer for this description?
  def is_writer?(user); has_permission?(writers_join_table, user); end

  # Is a given user an reader for this description?
  def is_reader?(user); has_permission?(readers_join_table, user); end

  # Give a User or UserGroup admin privileges.
  def add_admin(arg); chg_permission(admins, arg, :add); end

  # Give a User or UserGroup writer privileges.
  def add_writer(arg); chg_permission(writers, arg, :add); end

  # Give a User or UserGroup reader privileges.
  def add_reader(arg); chg_permission(readers, arg, :add); end

  # Revoke a User's or UserGroup's admin privileges.
  def remove_admin(arg); chg_permission(admins, arg, :remove); end

  # Revoke a User's or UserGroup's writer privileges.
  def remove_writer(arg); chg_permission(writers, arg, :remove); end

  # Revoke a User's or UserGroup's reader privileges.
  def remove_reader(arg); chg_permission(readers, arg, :remove); end

  # Change a given User's or UserGroup's privileges.
  def chg_permission(groups, arg, mode)
    if arg.is_a?(User)
      arg = UserGroup.one_user(arg)
    end
    if (mode == :add) and
       !groups.include?(arg)
      groups.push(arg)
    elsif (mode == :remove) and
          groups.include?(arg)
      groups.delete(arg)
    end
  end

  # Check if a given user has the given type of permission.
  def has_permission?(table, user)
    if user.is_a?(User)
      user.admin || group_user_ids(table).include?(user.id)
    elsif !user
      group_ids(table).include?(UserGroup.all_users)
    elsif user.to_i != 0
      group_user_ids(table).include?(user.to_i)
    else
      raise "ArgumentError", "Was expecting User instance, id or nil."
    end
  end

  # Do minimal query to enumerate the users in a list of groups.  Return as an
  # Array of User instances.  Caches result.
  def group_users(table)
    @group_users ||= {}
    @group_users[table] ||= User.find_by_sql %(
      SELECT * FROM users
      WHERE id IN (#{
        ids = group_user_ids(table)
        ids = ['-1'] if ids.empty?
        ids.map(&:to_s).join(',')
      })
    )
  end

  # Do minimal query to enumerate the users in a list of groups.  Return as an
  # Array of ids.  Caches result.
  def group_user_ids(table)
    @group_user_ids ||= {}
    @group_user_ids[table] ||= self.class.connection.select_values(%(
      SELECT DISTINCT t.user_group_id FROM #{table} t, user_groups_users u
      WHERE t.#{self.class.name.underscore}_id = #{id}
        AND t.user_group_id = u.user_group_id
      ORDER BY t.user_group_id ASC
    )).map(&:to_i)
  end

  # Do minimal query to enumerate a list of groups.  Return as an Array of ids.
  # Caches result.  (Equivalent to using <tt>association.ids</tt>, I think.)
  def group_ids(table)
    @group_ids ||= {}
    @group_ids[table] ||= self.class.connection.select_values(%(
      SELECT DISTINCT user_group_id FROM #{table}
      WHERE #{self.class.name.underscore}_id = #{id}
      ORDER BY user_group_id ASC
    )).map(&:to_i)
  end

  ##############################################################################
  #
  #  :section: Authors and Editors
  #
  ##############################################################################

  # Name of the join table used to keep authors.
  def self.authors_join_table; "#{table_name}_authors".to_sym; end

  # Name of the join table used to keep authors.
  def authors_join_table; "#{self.class.table_name}_authors".to_sym; end

  # Name of the join table used to keep editors.
  def self.editors_join_table; "#{table_name}_editors".to_sym; end

  # Name of the join table used to keep editors.
  def editors_join_table; "#{self.class.table_name}_editors".to_sym; end

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
    if not authors.member?(user)
      authors.push(user)
      SiteData.update_contribution(:add, self, authors_join_table, user)
      if editors.member?(user)
        editors.delete(user)
        SiteData.update_contribution(:remove, self, editors_join_table, user)
      end
    end
  end

  # Demote a User to "editor".  Saves User if changed.  Returns nothing.
  def remove_author(user)
    if authors.member?(user)
      authors.delete(user)
      SiteData.update_contribution(:remove, self, authors_join_table, user)
      if not editors.member?(user) and
        # Make sure user has actually made at least one change.
        self.class.connection.select_value %(
          SELECT id FROM #{versioned_table_name}
          WHERE #{self.class.name.underscore}_id = #{id} AND user_id = #{user.id}
          LIMIT 1
        )
        editors.push(user)
        SiteData.update_contribution(:add, self, editors_join_table, user)
      end
    end
  end

  # Add a user on as an "editor".
  def add_editor(user)
    if not authors.member?(user) and not editors.member?(user)
      editors.push(user)
      SiteData.update_contribution(:add, self, editors_join_table, user)
    end
  end

  ################################################################################
  #
  #  :section: Callbacks
  #
  ################################################################################

  # Callback that updates editors and/or authors after a User makes a change.
  # If the Name has no author and they've made sufficient contributions, they
  # get promoted to author by default.  In all cases make sure the user is
  # added on as an editor.
  def before_save
    if !@save_without_our_callbacks and
       (user = User.current)
      if authors.empty? && has_any_notes?
        add_author(user)
      else
        add_editor(user)
      end
    end
    super
  end

  # When destroying an object, subtract contributions due to
  # authorship/editorship.
  def before_destroy
    for user in authors
      SiteData.update_contribution(:remove, self, authors_join_table, user)
    end
    for user in editors
      SiteData.update_contribution(:remove, self, editors_join_table, user)
    end
    super
  end
end
