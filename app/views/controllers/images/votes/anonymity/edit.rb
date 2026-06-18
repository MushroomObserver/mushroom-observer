# frozen_string_literal: true

module Views::Controllers::Images
  module Votes
    module Anonymity
      # Image-vote-anonymity edit page. Wrap of `Anonymity::Form`.
      # Converted from `images/votes/anonymity/edit.html.erb`.
      class Edit < Views::FullPageBase
        prop :num_anonymous, ::Integer
        prop :num_public, ::Integer

        def view_template
          add_page_title(:image_vote_anonymity_title.t)
          render(Form.new(
                   ::FormObject::ImageVoteAnonymity.new(
                     num_anonymous: @num_anonymous,
                     num_public: @num_public
                   )
                 ))
        end
      end
    end
  end
end
