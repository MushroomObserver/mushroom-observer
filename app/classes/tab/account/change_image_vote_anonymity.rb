# frozen_string_literal: true

# "Change image-vote anonymity" preference link.
class Tab::Account::ChangeImageVoteAnonymity < Tab::Base
  def title
    :prefs_change_image_vote_anonymity.t
  end

  def path
    images_edit_vote_anonymity_path
  end
end
