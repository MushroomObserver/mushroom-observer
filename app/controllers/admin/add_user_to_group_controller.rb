# frozen_string_literal: true

module Admin
  class AddUserToGroupController < AdminController
    def new; end

    def create
      form = FormObject::AddUserToGroup.new(form_params)

      if form.save
        flash_notice(:add_user_to_group_success.
          t(user: form.user.name, group: form.group.name))
      else
        form.errors.full_messages.each do |message|
          flash_error(message)
        end
      end

      redirect_back_or_default("/")
    end

    private

    def form_params
      params.require(:add_user_to_group).permit(:user_name, :group_name)
    end
  end
end
