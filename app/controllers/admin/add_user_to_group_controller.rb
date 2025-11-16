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
        # Check if the only error is "already in group" - if so, it's a warning
        if form.errors.count == 1 &&
           form.errors[:base].any? { |msg| msg.match?(/already a member/) }
          flash_warning(form.errors.full_messages.first)
        else
          form.errors.full_messages.each do |message|
            flash_error(message)
          end
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
