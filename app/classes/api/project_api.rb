# API
class API
  # API for Project
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
        where:             sql_id_condition,
        created_at:        parse_time_range(:created_at),
        updated_at:        parse_time_range(:updated_at),
        users:             parse_users(:user),
        has_images:        parse_boolean(:has_images, limit: true),
        has_observations:  parse_boolean(:has_observations, limit: true),
        has_species_lists: parse_boolean(:has_species_lists, limit: true),
        has_comments:      parse_boolean(:has_comments, limit: true),
        has_notes:         parse_boolean(:has_notes),
        title_has:         parse_string(:title_has),
        notes_has:         parse_string(:notes_has),
        comments_has:      parse_string(:comments_has)
      }
    end

    def create_params
      @admins  = parse_users(:admins, default: [user])
      @members = parse_users(:members, default: [user])
      {
        title:   parse_string(:title, limit: 100),
        summary: parse_string(:summary)
      }
    end

    def validate_create_params!(params)
      @title = params[:title].to_s
      @title2 = @title + ".admin"
      raise MissingParameter.new(:title) if @title.blank?
      raise ProjectTaken.new(@title)     if Project.find_by_title(@title)
      raise UserGroupTaken.new(@title)   if UserGroup.find_by_name(@title)
      raise UserGroupTaken.new(@title2)  if UserGroup.find_by_name(@title2)
    end

    def before_create
      member_group = UserGroup.new(
        name:  @title,
        users: @members
      )
      admin_group = UserGroup.new(
        name:  @title2,
        users: @admins
      )
      member_group.save || raise(CreateFailed.new(member_group))
      admin_group.save  || raise(CreateFailed.new(admin_group))
      params[:user_group]  = member_group
      params[:admin_group] = admin_group
    end

    def build_setter
      params = parse_setting_parameters
      lambda do |proj|
        raise MustBeAdmin.new(proj) unless proj.is_admin?(@user)
        proj.update!(params) unless params.empty?
        update_admin_group(proj)
        update_user_group(proj)
        update_images(proj)
        update_observations(proj)
        update_species_lists(proj)
      end
    end

    def update_admin_group(proj)
      proj.admin_group.users.push(@add_admins)      if @add_admins.any?
      proj.admin_group.users.delete(@remove_admins) if @remove_admins.any?
    end

    def update_user_group(proj)
      proj.user_group.users.push(@add_members)      if @add_members.any?
      proj.user_group.users.delete(@remove_members) if @remove_members.any?
    end

    def update_images(proj)
      proj.add_images(@add_images)       if @add_imgs.any?
      proj.remove_images(@remove_images) if @remove_imgs.any?
    end

    def update_observations(proj)
      proj.add_observations(@add_obs)       if @add_obs.any?
      proj.remove_observations(@remove_obs) if @remove_obs.any?
    end

    def update_species_lists(proj)
      proj.add_species_lists(@add_spls)       if @add_spls.any?
      proj.remove_species_lists(@remove_spls) if @remove_spls.any?
    end

    def parse_setting_parameters
      params = update_params
      parse_add_remove_admins
      parse_add_remove_members
      parse_add_remove_images
      parse_add_remove_observations
      parse_add_remove_species_lists
      params.remove_nils!
      make_sure_parameters_not_empty!
      params
    end

    def update_params
      {
        title:   parse_string(:set_title, limit: 100),
        summary: parse_string(:set_summary)
      }
    end

    def parse_add_remove_admins
      @add_admins    = parse_users(:add_admins) || []
      @remove_admins = parse_users(:remove_admins) || []
    end

    def parse_add_remove_members
      @add_members    = parse_users(:add_members) || []
      @remove_members = parse_users(:remove_members) || []
    end

    def parse_add_remove_images
      @add_imgs    = parse_images(:add_images) || []
      @remove_imgs = parse_images(:remove_images) || []
    end

    def parse_add_remove_observations
      @add_obs    = parse_observations(:add_observations) || []
      @remove_obs = parse_observations(:remove_observations) || []
    end

    def parse_add_remove_species_lists
      @add_spls    = parse_species_lists(:add_species_lists) || []
      @remove_spls = parse_species_lists(:remove_species_lists) || []
    end

    def make_sure_parameters_not_empty!
      return unless params.empty? && adds_and_removes.empty?
      raise MissingSetParameters.new
    end

    def adds_and_removes
      @add_admins + @remove_admins + @add_members + @remove_members +
        @add_imgs + @remove_imgs + @add_obs + @remove_obs + @add_spls +
        @remove_spls
    end

    def delete
      raise NoMethodForAction.new("DELETE", action)
    end
  end
end
