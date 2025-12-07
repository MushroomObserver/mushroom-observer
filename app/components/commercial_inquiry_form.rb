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
      render_user_label
      render_message_field
      submit(:SEND.l, center: true)
    end
  end

  private

  def render_image_preview
    div(class: "mb-4") do
      render(Components::InteractiveImage.new(
               user: @user,
               image: @image,
               size: :medium,
               votes: false
             ))
    end
  end

  def render_user_label
    bold_user = "**#{@image.user.legal_name}**"
    p { :commercial_inquiry_header.t(user: bold_user) }
  end

  def render_message_field
    label = "#{:ask_user_question_message.t}:"
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
