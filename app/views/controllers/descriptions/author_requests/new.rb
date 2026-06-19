# frozen_string_literal: true

# Action view for `descriptions/author_requests#new`. Sets the page
# title and renders the email-compose form.
module Views::Controllers::Descriptions::AuthorRequests
  class New < Views::FullPageBase
    prop :object, ::AbstractModel

    def view_template
      add_page_title(:author_request_title.t(title: @object.format_name))

      render(Form.new(
               ::FormObject::EmailRequest.new,
               object: @object,
               action: description_author_requests_path(
                 id: @object.id, type: @object.type_tag
               )
             ))
    end
  end
end
