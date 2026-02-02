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
  include Phlex::Rails::Helpers::CheckBoxTag

  register_value_helper :in_admin_mode?
  register_output_helper :user_link, mark_safe: true

  WRITEIN_ROWS = 6

  def initialize(description:, groups:, data:)
    @description = description
    @groups = groups
    form_object = FormObject::DescriptionPermissions.new
    form_object.load_writein_data(data) if data
    super(form_object, id: "description_permissions_form")
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
    args = checkbox_args_for_group(group)

    tr do
      td { render_group_name(group) }
      td { check_box_tag("group_reader[#{group.id}]", *args[:reader]) }
      td { check_box_tag("group_writer[#{group.id}]", *args[:writer]) }
      td { check_box_tag("group_admin[#{group.id}]", *args[:admin]) }
    end
  end

  def checkbox_args_for_group(group)
    if locked_all_users_group?(group)
      {
        reader: ["1", true, { disabled: "disabled", class: "form-control" }],
        writer: ["1", true, { disabled: "disabled", class: "form-control" }],
        admin: ["1", false, { disabled: "disabled", class: "form-control" }]
      }
    elsif locked_reviewers_group?(group)
      {
        reader: ["1", false, { disabled: "disabled", class: "form-control" }],
        writer: ["1", false, { disabled: "disabled", class: "form-control" }],
        admin: ["1", true, { disabled: "disabled", class: "form-control" }]
      }
    else
      {
        reader: ["1", @description.reader_groups.include?(group),
                 { class: "form-control" }],
        writer: ["1", @description.writer_groups.include?(group),
                 { class: "form-control" }],
        admin: ["1", @description.admin_groups.include?(group),
                { class: "form-control" }]
      }
    end
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
      td do
        autocompleter_field(
          :"writein_name_#{row_num}",
          type: :user,
          placeholder: :start_typing.l,
          attributes: { name: "writein_name[#{row_num}]" }
        )
      end
      td do
        check_box_tag("writein_reader[#{row_num}]", "1",
                      model.send(:"writein_reader_#{row_num}"),
                      class: "form-control")
      end
      td do
        check_box_tag("writein_writer[#{row_num}]", "1",
                      model.send(:"writein_writer_#{row_num}"),
                      class: "form-control")
      end
      td do
        check_box_tag("writein_admin[#{row_num}]", "1",
                      model.send(:"writein_admin_#{row_num}"),
                      class: "form-control")
      end
    end
  end

  def name_description?
    @description.is_a?(NameDescription)
  end

  def form_action
    url_for(controller: permissions_controller, action: :update,
            id: @description.id, only_path: true)
  end

  def permissions_controller
    if name_description?
      "/names/descriptions/permissions"
    else
      "/locations/descriptions/permissions"
    end
  end

  def form_method
    :put
  end
end
