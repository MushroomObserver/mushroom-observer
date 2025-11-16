# frozen_string_literal: true

module Admin
  class AddUserToGroupController < AdminController
    def new; end

    def create
      form = FormObject::AddUserToGroup.new(form_params)

      if form.save
        flash_success(form)
      else
        flash_errors(form)
      end

      redirect_back_or_default("/")
    end

    private

    def flash_success(form)
      flash_notice(:add_user_to_group_success.
        t(user: form.user.name, group: form.group.name))
    end

    def flash_errors(form)
      if already_member_error?(form)
        flash_warning(form.errors.full_messages.first)
      else
        form.errors.full_messages.each { |message| flash_error(message) }
      end
    end

    def already_member_error?(form)
      form.errors.one? &&
        form.errors[:base].any? { |msg| msg.match?(/already a member/) }
    end

    def form_params
      params.require(:add_user_to_group).permit(:user_name, :group_name)
    end
  end
end
