# frozen_string_literal: true

module Views::Controllers::Herbaria::CuratorRequests
  # Action view for the herbarium curator-request form. Replaces
  # new.html.erb.
  class New < Views::FullPageBase
    def initialize(herbarium:, back: nil)
      super()
      @herbarium = herbarium
      @back = back
    end

    def view_template
      add_page_title(:show_herbarium_curator_request.t)
      add_context_nav(
        ::Tab::Herbarium::CuratorRequest.new(herbarium: @herbarium,
                                             q_param: q_param)
      )
      trusted_html(:show_herbarium_curator_help.tp)
      render(Views::Controllers::Herbaria::CuratorRequests::Form.new(
               FormObject::HerbariumCuratorRequest.new,
               herbarium: @herbarium, back: @back, q_param: q_param
             ))
    end
  end
end
