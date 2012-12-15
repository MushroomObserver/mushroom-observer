module HerbariumHelper
  
  def curator_table(title, herbarium, can_delete)
    curators = herbarium.curators
    "<table>" + title_row(curators.count, title) + herbarium.curators.map {|u| curator_row(u, herbarium, can_delete)}.join() + "</table>"
  end
  
  def title_row(count, title)
    "<tr><td colspan=\"2\"><b>" + pluralize(count, title) + ":</b></td></tr>"
  end
  
  def curator_row(user, herbarium, can_delete)
    "<tr><td>" + delete_link(user, herbarium, can_delete) + "</td><td>" + user_link(user, user.legal_name) + "</td></tr>"
  end

  def delete_link(user, herbarium, can_delete)
    can_delete ? link_to('X', {:action => 'delete_curator', :id => herbarium.id, :user => user.id}, {:confirm => :are_you_sure.t}) : ""
  end
end
