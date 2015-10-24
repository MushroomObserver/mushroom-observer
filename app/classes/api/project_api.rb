# encoding: utf-8

class API
  class ProjectAPI < ModelAPI
    self.model = Project

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :comments,
      :user
    ]

    def query_params
      {
        where: sql_id_condition,
        created_at: parse_time_range(:created_at),
        updated_at: parse_time_range(:updated_at),
        users: parse_users(:user),
        has_images: parse_boolean(:has_images, limit: true),
        has_observations: parse_boolean(:has_observations, limit: true),
        has_species_lists: parse_boolean(:has_species_lists, limit: true),
        has_comments: parse_boolean(:has_comments, limit: true),
        has_notes: parse_boolean(:has_notes),
        title_has: parse_string(:title_has),
        notes_has: parse_string(:notes_has),
        comments_has: parse_string(:comments_has)
      }
    end

    def build_object
      admins  = parse_users(:admins, default: [user])
      members = parse_users(:members, default: [user])
      params = {
        title: parse_string(:title, limit: 100),
        summary: parse_string(:summary)
      }
      done_parsing_parameters!

      title = params[:title].to_s
      admin_title = title + ".admin"
      fail MissingParameter.new(:title) if title.blank?
      fail ProjectTaken.new(title) if Project.find_by_title(title)
      fail UserGroupTaken.new(title) if UserGroup.find_by_name(title)
      fail UserGroupTaken.new(admin_title) if UserGroup.find_by_name(admin_title)

      admin_group = UserGroup.new(
        name: title,
        users: admins
      )
      admin_group.save || fail(CreateFailed.new(admin_group))

      member_group = UserGroup.new(
        name: title,
        users: members
      )
      member_group.save || fail(CreateFailed.new(member_group))

      params[:admin_group] = admin_group
      params[:user_group] = member_group
      proj = Project.new(params)
      proj.save || fail(CreateFailed.new(proj))
      proj
    end

    def build_setter
      add_admins = parse_projects(:add_admins) || []
      remove_admins = parse_projects(:remove_admins) || []
      add_members = parse_projects(:add_members) || []
      remove_members = parse_projects(:remove_members) || []
      add_images = parse_projects(:add_images) || []
      remove_images = parse_projects(:remove_images) || []
      add_observations = parse_projects(:add_observations) || []
      remove_observations = parse_projects(:remove_observations) || []
      add_species_lists = parse_projects(:add_species_lists) || []
      remove_species_lists = parse_projects(:remove_species_lists) || []
      params = {
        title: parse_string(:set_title, limit: 100),
        summary: parse_string(:set_summary)
      }
      params.remove_nils!

      if params.empty? &&
         add_admins.empty? &&
         remove_admins.empty? &&
         add_members.empty? &&
         remove_members.empty? &&
         add_images.empty? &&
         remove_images.empty? &&
         add_observations.empty? &&
         remove_observations.empty? &&
         add_species_lists.empty? &&
         remove_species_lists.empty?
        fail MissingSetParameters.new
      end

      lambda do |proj|
        fail MustBeAdmin.new(proj) unless proj.is_admin?(user)
        proj.update!(params)
        proj.admin_group.users.push(add_admins) if add_admins.any?
        proj.admin_group.users.delete(remove_admins) if remove_admins.any?
        proj.user_group.users.push(add_members) if add_members.any?
        proj.user_group.users.delete(remove_members) if remove_members.any?
        proj.add_images(add_images) if add_images.any?
        proj.remove_images(remove_images) if remove_images.any?
        proj.add_observations(add_observations) if add_observations.any?
        proj.remove_observations(remove_observations) if remove_observations.any?
        proj.add_species_lists(add_species_lists) if add_species_lists.any?
        proj.remove_species_lists(remove_species_lists) if remove_species_lists.any?
      end
    end

    def delete
      fail NoMethodForAction("DELETE", action)
    end
  end
end
