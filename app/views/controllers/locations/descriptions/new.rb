# frozen_string_literal: true

module Views::Controllers::Locations::Descriptions
  class New < Views::FullPageBase
    prop :location, ::Location
    prop :description, ::LocationDescription
    prop :user, _Nilable(::User), default: nil
    prop :licenses, _Array(_Tuple(String, Integer)), default: -> { [] }

    def view_template
      add_page_title(:create_location_description_title.t(
                       name: @location.display_name
                     ))
      add_context_nav(::Tab::LocationDescription::FormNew.new(
                        description: @description
                      ))

      render(Views::Controllers::Descriptions::Form.new(
               @description, licenses: @licenses, user: @user
             ))
    end
  end
end
