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
      :user,
    ]

    def query_params
      {
        :where        => sql_id_condition,
        :created      => parse_time_ranges(:created),
        :modified     => parse_time_ranges(:modified),
        :users        => parse_users(:user),
        :has_comments => parse_boolean(:has_comments, :limit => true),
      }
    end

    def build_object
      admins  = parse_users(:admins, :default => [user])
      members = parse_users(:members, :default => [user])
      params = {
        :title   => parse_string(:title, :limit => 100),
        :summary => parse_string(:summary),
      }
      done_parsing_parameters!

      title = params[:title].to_s
      admin_title = title + '.admin'
      raise MissingParameter.new(:title) if title.blank?
      raise ProjectTaken.new(title) if Project.find_by_title(title)
      raise UserGroupTaken.new(title) if UserGroup.find_by_name(title)
      raise UserGroupTaken.new(admin_title) if UserGroup.find_by_name(admin_title)

      admin_group = UserGroup.new(
        :name  => title,
        :users => admins
      )
      admin_group.save or raise CreateFailed.new(admin_group)

      member_group = UserGroup.new(
        :name  => title,
        :users => members
      )
      member_group.save or raise CreateFailed.new(member_group)

      params[:admin_group] = admin_group
      params[:user_group] = member_group
      proj = Project.new(params)
      proj.save or raise CreateFailed.new(proj)
      return proj
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
        :title   => parse_string(:set_title, :limit => 100),
        :summary => parse_string(:set_summary),
      }
      params.remove_nils!

      if params.empty? and
         add_admins.empty? and
         remove_admins.empty? and
         add_members.empty? and
         remove_members.empty? and
         add_images.empty? and
         remove_images.empty? and
         add_observations.empty? and
         remove_observations.empty? and
         add_species_lists.empty? and
         remove_species_lists.empty?
        raise MissingSetParameters.new
      end

      lambda do |proj|
        raise MustBeAdmin.new(proj) unless proj.is_admin?(user)
        proj.update_attributes!(params)
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
      raise NoMethodForAction(:delete, action)
    end
  end
end
