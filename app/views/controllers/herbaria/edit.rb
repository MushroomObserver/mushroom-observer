# frozen_string_literal: true

module Views::Controllers::Herbaria
  # Action view for the edit herbarium form page. Replaces
  # edit.html.erb.
  class Edit < Views::Base
    def initialize(herbarium:, user:, top_users:)
      super()
      @herbarium = herbarium
      @user = user
      @top_users = top_users
    end

    def view_template
      add_edit_title(@herbarium)
      add_context_nav(::Tab::Herbarium::FormEdit.new(herbarium: @herbarium,
                                                     q_param: q_param))

      render(Views::Controllers::Herbaria::Form.new(
               @herbarium, user: @user, local: true,
                           location: @herbarium.location, top_users: @top_users
             ))
    end
  end
end
