# frozen_string_literal: true

# Form for sending a commercial inquiry about an image.
# Allows users to contact image owners about licensing.
class Components::CommercialInquiryForm < Components::ApplicationForm
  def initialize(model, image:, user: nil, message: nil, **)
    @image = image
    @user = user
    @message = message
    super(model, **)
  end

  def view_template
    super do
      render_image_preview
      render_message_field
      submit(:SEND.l, center: true)
    end
  end

  private

  def render_image_preview
    div do
      render(Components::InteractiveImage.new(
               user: @user,
               image: @image,
               size: :medium,
               votes: false
             ))
    end
  end

  def render_message_field
    label = :commercial_inquiry_header.tp(user: @image.user.legal_name)
    render(field(:message).textarea(
             wrapper_options: { label: label },
             value: @message,
             rows: 10
           ))
  end

  def form_action
    url_for(action: :create, id: @image.id)
  end
end
