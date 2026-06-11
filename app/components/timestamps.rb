# frozen_string_literal: true

# Centered `Created at` / `Updated at` block used at the bottom of
# many show pages. Renders:
#
#   <div class="text-center">
#     <p>
#       Created at: <web_date><br>
#       Updated at: <web_date><br>
#     </p>
#   </div>
#
# @example
#   render(Components::Timestamps.new(object: @collection_number))
class Components::Timestamps < Components::Base
  prop :object, ::AbstractModel

  def view_template
    div(class: "text-center") do
      p do
        trusted_html(:CREATED_AT.t)
        plain(": #{@object.created_at.web_date}")
        br
        trusted_html(:UPDATED_AT.t)
        plain(": #{@object.updated_at.web_date}")
        br
      end
    end
  end
end
