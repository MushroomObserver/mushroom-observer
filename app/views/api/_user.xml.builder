xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "user"
) do
  xml_string(xml, :login_name, object.login)
  xml_string(xml, :legal_name, object.legal_name)
  xml_date(xml, :joined, object.created_at)
  xml_date(xml, :verified, object.verified)
  xml_datetime(xml, :last_login, object.last_login)
  xml_datetime(xml, :last_activity, object.last_activity)
  xml_integer(xml, :contribution, object.contribution)
  xml_html_string(xml, :notes, object.notes.to_s.tpl_nodiv)
  xml_string(xml, :mailing_address,
             object.mailing_address.to_s.tpl_nodiv.html_to_ascii)
  if !detail
    xml_minimal_object_old(xml, :location, Location, object.location_id)
    xml_minimal_object_old(xml, :image, Image, object.image_id)
  else
    xml_detailed_object_old(xml, :location, object.location)
    xml_detailed_object_old(xml, :image, object.image)
    if @user == object or
       # (special exception: show API keys of new user when API creates new
       # user)
       @show_api_keys_for_new_user
      if object.api_keys.any?
        xml.api_keys(number: object.api_keys.length) do
          for api_key in object.api_keys
            xml_detailed_object_old(xml, :api_key, api_key)
          end
        end
      end
    end
  end
end
