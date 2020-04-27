# see ajax_controller.rb
class AjaxController
  # Cast vote. Renders new set of vote controls for HTML page if image,
  # nothing if naming.
  # type::  Type of object.
  # id::    ID of object.
  # value:: Value of vote.
  def vote
    @user = session_user!
    if @type == "naming"
      cast_naming_vote(@id, @value)
    elsif @type == "image"
      cast_image_vote(@id, @value)
    end
  end

  private

  def cast_naming_vote(id, value_str)
    @naming = Naming.find(id)
    value = Vote.validate_value(value_str)
    raise "Bad value." unless value

    @naming.change_vote(value, @user)
    @observation = @naming.observation
    @votes = gather_users_votes(@observation, @user)
    render(inline: %(<div>
      <%= content_tag(:div, show_obs_title(@observation),
            title: show_obs_title(@observation).strip_html.html_safe) %>
      <%= content_tag(:div, render(partial: 'naming/show',
            locals: { observation: @observation })) %>
    </div>))
  end

  def cast_image_vote(id, value)
    image = Image.find(id)
    raise "Bad value." if value != "0" && !Image.validate_vote(value)

    value = value == "0" ? nil : Image.validate_vote(value)
    anon = (@user.votes_anonymous == :yes)
    image.change_vote(@user, value, anon)
    render(partial: "images/image_vote_links", locals: { image: image })
  end
end
