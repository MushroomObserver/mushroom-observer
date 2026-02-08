# frozen_string_literal: true

# Form for sending a commercial inquiry about an image.
# Creates its own FormObject internally from the provided kwargs.
class Components::CommercialInquiryForm < Components::ApplicationForm
  # Accept optional model arg for ModalForm compatibility (ignored - we create
  # our own FormObject). This is Pattern B: form creates FormObject internally.
  def initialize(_model = nil, image:, user: nil, message: nil, **)
    @image = image
    @user = user

    form_object = FormObject::EmailRequest.new(message: message)
    super(form_object, **)
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
    textarea_field(:message, label: "#{:ask_user_question_message.t}:",
                             rows: 10)
  end

  def form_action
    url_for(action: :create, id: @image.id)
  end
end
