# frozen_string_literal: true

# Form for editing permissions on a description.
# Allows setting reader/writer/admin permissions for groups and users.
# Used for both NameDescription and LocationDescription.
#
# Note: This form uses dynamic field names (group_reader[14], writein_name[1])
# that don't map to model attributes. We use check_box_tag for the checkboxes
# and ApplicationForm's autocompleter_field for the writeins.
#
class Components::Descriptions::PermissionsForm < Components::ApplicationForm
  register_value_helper :in_admin_mode?
  register_output_helper :user_link, mark_safe: true

  WRITEIN_ROWS = 6

  def initialize(description:, groups:, data:)
    @description = description
    @groups = groups
    form_object = FormObject::DescriptionPermissions.new(
      group_reader: description.reader_group_ids,
      group_writer: description.writer_group_ids,
      group_admin: description.admin_group_ids
    )
    form_object.load_writein_data(data) if data
    super(form_object, id: "description_permissions_form", method: :put)
  end

  def view_template
    submit(:SUBMIT.l, center: true)
    render_permissions_table
    submit(:SUBMIT.l, center: true)
  end

  private

  def render_permissions_table
    table(class: "w-100 table-striped table-description-permissions") do
      render_table_header
      tbody { render_table_body }
    end
  end

  def render_table_header
    thead do
      tr do
        th(style: "mr-4") { :adjust_permissions_user_header.t }
        th(width: "50") { :adjust_permissions_reader_header.t }
        th(width: "50") { :adjust_permissions_writer_header.t }
        th(width: "50") { :adjust_permissions_admin_header.t }
      end
    end
  end

  def render_table_body
    @groups.each { |group| render_group_row(group) }
    WRITEIN_ROWS.times { |idx| render_writein_row(idx + 1) }
  end

  def render_group_row(group)
    tr do
      td { render_group_name(group) }
      td { render_group_checkbox(:group_reader, group) }
      td { render_group_checkbox(:group_writer, group) }
      td { render_group_checkbox(:group_admin, group) }
    end
  end

  def render_group_checkbox(field_name, group)
    render(
      field(field_name).checkbox(wrapper_options: { label: false })
    ) do |cb|
      cb.option(group.id)
    end
  end

  def group_checked?(group, type)
    if locked_all_users_group?(group)
      type != :admin
    elsif locked_reviewers_group?(group)
      type == :admin
    else
      @description.send(:"#{type}_groups").include?(group)
    end
  end

  def group_locked?(group)
    locked_all_users_group?(group) || locked_reviewers_group?(group)
  end

  def locked_all_users_group?(group)
    group.name == "all users" &&
      @description.source_type.to_s == "public" &&
      !in_admin_mode?
  end

  def locked_reviewers_group?(group)
    group.name == "reviewers" &&
      @description.source_type.to_s == "public" &&
      !in_admin_mode?
  end

  def render_group_name(group)
    if personal_group?(group)
      render_personal_group_name(group)
    else
      render_standard_group_name(group)
    end
  end

  def personal_group?(group)
    group.name.match?(/^user \d+$/)
  end

  def render_standard_group_name(group)
    case group.name
    when "all users"
      plain(:adjust_permissions_all_users.t)
    when "reviewers"
      plain(:REVIEWERS.t)
    else
      plain(group.name)
    end
  end

  def render_personal_group_name(group)
    user = group.users.first
    user_link(user)
    render_user_roles(user) if user
  end

  def render_user_roles(user)
    words = collect_user_roles(user)
    return if words.empty?

    plain(" (")
    plain(words.join(", "))
    plain(")")
  end

  def collect_user_roles(user)
    group_memberships(user) + description_roles(user) + site_roles(user)
  end

  def description_roles(user)
    roles = []
    roles << :author.t if @description.author?(user)
    roles << :editor.t if @description.editor?(user)
    roles << :owner.t if @description.user == user
    roles
  end

  def site_roles(user)
    roles = []
    roles << :adjust_permissions_site_admin.t if user.admin
    roles << :reviewer.t if user.in_group?("reviewers")
    roles
  end

  def group_memberships(user)
    @groups.filter_map do |g|
      next if g.name == "all users"
      next if g.name == "reviewers"
      next if g.name.match?(/^user \d+$/)
      next unless g.users.include?(user)

      g.name
    end
  end

  def render_writein_row(row_num)
    tr do
      td { autocompleter_field(:"writein_name_#{row_num}", type: :user) }
      td { render_checkbox_field(:"writein_reader_#{row_num}") }
      td { render_checkbox_field(:"writein_writer_#{row_num}") }
      td { render_checkbox_field(:"writein_admin_#{row_num}") }
    end
  end

  def render_checkbox_field(field_name)
    render(field(field_name).checkbox(class: "form-control"))
  end

  def name_description?
    @description.is_a?(NameDescription)
  end

  def form_action
    if name_description?
      permissions_name_description_path(@description.id)
    else
      permissions_location_description_path(@description.id)
    end
  end
end
