# frozen_string_literal: true

# see ajax_controller.rb
module AjaxController::Vote
  # Cast vote. Renders new set of vote controls for HTML page if image,
  # nothing if naming.
  # type::  Type of object.
  # id::    ID of object.
  # value:: Value of vote.
  def vote
    @user = session_user!
    case @type
    when "image"
      cast_image_vote(@id, @value)
    end
  end

  private

  def cast_image_vote(id, value)
    image = Image.find(id)
    raise("Bad value.") if value != "0" && !Image.validate_vote(value)

    value = value == "0" ? nil : Image.validate_vote(value)
    anon = (@user.votes_anonymous == "yes")
    image.change_vote(@user, value, anon: anon)
    render(partial: "shared/image_vote_links", locals: { image: image })
  end
end
