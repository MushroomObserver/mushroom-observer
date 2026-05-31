# frozen_string_literal: true

module Views::Controllers::Descriptions::Permissions
  # Form for editing permissions on a description. Allows setting
  # reader/writer/admin permissions for groups and users. Used for both
  # NameDescription and LocationDescription, so it lives in the shared
  # `descriptions/` namespace.
  #
  # Note: This form uses dynamic field names (group_reader[14],
  # writein_name[1]) that don't map to model attributes. We use
  # checkbox_field on the FormObject and autocompleter_field for the
  # writeins.
  #
  # NOTE: Does NOT use `Components::Table` — the body has TWO row
  # shapes (one per existing group + N write-in rows that don't
  # correspond to a row object). Components::Table's row mode could
  # cover this with a flatten-and-tag trick, but the two row types
  # are different enough (group cells bind to existing group data;
  # write-in rows are blank slots with autocompleter fields) that
  # the resulting `row { ... }` block would mostly be a case-switch
  # on the row shape. Hand-rolled is clearer.
  class Form < ::Components::ApplicationForm
    register_value_helper :in_admin_mode?

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
      # Keep the explicit DOM id — integration tests reference it.
      super(form_object, id: "description_permissions_form", method: :put)
    end

    def view_template
      submit(:SUBMIT.l, center: true)
      render_permissions_table
      submit(:SUBMIT.l, center: true)
    end

    private

    def render_permissions_table
      table(class: "w-100 table table-description-permissions") do
        render_table_header
        tbody { render_table_body }
      end
    end

    def render_table_header
      thead do
        tr do
          th(style: "mr-4") { :adjust_permissions_user_header.l }
          th(width: "50") { :adjust_permissions_reader_header.l }
          th(width: "50") { :adjust_permissions_writer_header.l }
          th(width: "50") { :adjust_permissions_admin_header.l }
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
      checkbox_field(field_name,
                     label: false, wrap_class: "m-0",
                     label_class: "p-0") do |cb|
        cb.option(group.id)
      end
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
        plain(:adjust_permissions_all_users.l)
      when "reviewers"
        plain(:REVIEWERS.l)
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
      roles << :author.l if @description.author?(user)
      roles << :editor.l if @description.editor?(user)
      roles << :owner.l if @description.user == user
      roles
    end

    def site_roles(user)
      roles = []
      roles << :adjust_permissions_site_admin.l if user.admin
      roles << :reviewer.l if user.in_group?("reviewers")
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
      checkbox_field(field_name,
                     label: false, wrap_class: "m-0",
                     label_class: "p-0")
    end

    # Only a NameDescription path exists — there is no
    # `Locations::Descriptions::PermissionsController` (no route, no
    # controller, no callers). The `else` branch this method used to
    # carry referenced a `permissions_location_description_path` that
    # would have raised NoMethodError if ever rendered.
    def form_action
      permissions_name_description_path(@description.id)
    end
  end
end
