# frozen_string_literal: true

module Admin
  # The admins' list of iNat users with no MO account whose observations'
  # images and notes are not imported (#5521).
  class ExcludedInatUsersController < AdminController
    def index
      @excluded = ExcludedInatUser.new
      render_index_view
    end

    def create
      @excluded = ExcludedInatUser.new(excluded_params.merge(user: @user))
      if @excluded.save
        flash_notice(:excluded_inat_user_added.l(login: @excluded.inat_login))
        redirect_to(admin_excluded_inat_users_path)
      else
        @excluded.errors.full_messages.each { |msg| flash_error(msg) }
        render_index_view_invalid
      end
    end

    def destroy
      excluded = ExcludedInatUser.find(params[:id])
      excluded.destroy!
      flash_notice(:excluded_inat_user_removed.l(login: excluded.inat_login))
      redirect_to(admin_excluded_inat_users_path)
    end

    private

    def render_index_view(status: :ok, **render_opts)
      entries = ExcludedInatUser.includes(:user).order(:inat_login).to_a
      render(Views::Controllers::Admin::ExcludedInatUsers::Index.new(
               excluded: @excluded, entries: entries,
               purges: purges_for(entries)
             ), status: status, **render_opts)
    end

    def render_index_view_invalid(**)
      render_index_view(**)
      self.status = :unprocessable_content
    end

    # The latest purge of each listed login, by login.
    def purges_for(entries)
      ImagePurge.where(inat_login: entries.map(&:inat_login)).order(:id).
        index_by(&:inat_login)
    end

    def excluded_params
      params.require(:excluded_inat_user).permit(:inat_login, :reason)
    end
  end
end
