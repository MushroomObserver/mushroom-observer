# frozen_string_literal: true

# Links for a visual group's distinct consensus names (`VisualGroup
# #distinct_names`), shared by the show and edit pages -- each one
# renders through Name#format_name(user), the stored, author-aware
# display_name column, so bold/italic name markup matches every
# other name display in the app. `path_for` differs per caller (show
# filters the image matrix; edit filters + scrolls to the filter
# form), so it's supplied as a proc rather than hard-coded here.
module Views::Controllers::VisualGroups
  class DistinctNames < Views::Base
    prop :visual_group, VisualGroup
    prop :user, _Nilable(User), default: nil
    # (String) -> String : builds the target path for one text_name.
    prop :path_for, Proc

    def view_template
      @visual_group.distinct_names.each do |name|
        Link(type: :get, name: name.text_name,
             target: @path_for.call(name.text_name)) do
          trusted_html(name.format_name(@user).t)
        end
        br
      end
    end
  end
end
