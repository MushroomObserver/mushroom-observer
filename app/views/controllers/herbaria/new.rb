# frozen_string_literal: true

module Views::Controllers::Herbaria
  # Action view for the new herbarium form page. Replaces new.html.erb.
  class New < Views::FullPageBase
    def initialize(herbarium:, user:)
      super()
      @herbarium = herbarium
      @user = user
    end

    def view_template
      add_new_title(:new_object, :HERBARIUM)
      add_context_nav(::Tab::Herbarium::FormNew.new(q_param: q_param))

      render(Views::Controllers::Herbaria::Form.new(
               @herbarium, user: @user, local: true
             ))
    end
  end
end
