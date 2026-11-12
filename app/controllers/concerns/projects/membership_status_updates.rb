# frozen_string_literal: true

module Projects
  # Changing an existing member's admin/trust/membership status --
  # Projects::MembersController#update's dispatch and its mutators.
  module MembershipStatusUpdates
    # ProjectMember#trust_level enum value => the commit-button's
    # translation tag. The flash tag is the same name with a _flash
    # suffix (e.g. change_member_editing_trust =>
    # change_member_editing_trust_flash).
    COMMIT_TAG_BY_TRUST_LEVEL = {
      "no_trust" => :change_member_status_revoke_trust,
      "hidden_gps" => :change_member_hidden_gps_trust,
      "editing" => :change_member_editing_trust
    }.freeze

    private

    def update_membership(project, candidate)
      unless update_trust_status(project, candidate)
        unless update_admin_status(project, candidate)
          return must_be_project_admin!(project.id)
        end

        update_member_status(project, candidate)
      end
      return_to_caller(project, params[:target])
    end

    def update_trust_status(project, candidate)
      trust_level = COMMIT_TAG_BY_TRUST_LEVEL.keys.find do |level|
        params[:commit] == COMMIT_TAG_BY_TRUST_LEVEL[level].l
      end
      if trust_level
        apply_trust_level(project, candidate, trust_level)
      elsif params[:commit] == :change_member_add_obs.l
        apply_add_obs(project, candidate)
      else
        return false
      end
      true
    end

    def apply_trust_level(project, candidate, trust_level)
      commit_tag = COMMIT_TAG_BY_TRUST_LEVEL[trust_level]
      flash_notice(:"#{commit_tag}_flash".l)
      set_trust(project, candidate, trust_level)
    end

    def apply_add_obs(project, candidate)
      count = add_observations(project, candidate)
      flash_notice(:change_member_add_obs_flash.t(count: count))
    end

    def set_trust(project, user, trust_level)
      member = project.project_members.find_by(user:)
      member.update(trust_level:)
    end

    def update_admin_status(project, candidate)
      make_admin = (params[:commit] == :change_member_status_make_admin.l)
      if project.is_admin?(@user)
        set_status(project, :admin, candidate, make_admin)
      elsif make_admin
        return false
      end
      true
    end

    def update_member_status(project, candidate)
      make_member = [
        :change_member_status_make_admin.l,
        :change_member_status_make_member.l
      ].member?(params[:commit])
      set_status(project, :member, candidate, make_member)
    end

    # Add/remove a given User to/from a given UserGroup.
    # Changes should get logged
    def set_status(project, type, user, add)
      update_project_membership(project, type, user, add)
      group = project.send(type == :member ? :user_group : :admin_group)
      if add
        set_status_add(project, type, user, group)
      else
        set_status_remove(project, type, user, group)
      end
    end

    def update_project_membership(project, type, user, add)
      project_member = ProjectMember.find_by(project:, user:)
      unless project_member
        project_member = ProjectMember.create(project:, user:,
                                              trust_level: "editing")
        flash_notice(:add_members_with_editing.l)
      end
      return unless project_member
      return if type == :admin || add

      project_member.destroy
    end

    def set_status_add(project, type, user, group)
      if group.users.include?(user)
        flash_notice(:"add_members_already_added_#{type}".t(user: user.login))
      else
        group.add_user(user)
        project.send(:"log_add_#{type}", user)
        flash_notice(:"add_members_added_#{type}".t(user: user.login))
      end
    end

    def set_status_remove(project, type, user, group)
      if group.users.include?(user)
        group.users.delete(user)
        project.send(:"log_remove_#{type}", user)
        flash_notice(:"add_members_removed_#{type}".t(user: user.login))
      else
        flash_notice(:"add_members_already_removed_#{type}".t(user: user.login))
      end
    end
  end
end
