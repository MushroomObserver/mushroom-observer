module SemanticVernacularHelper
  
	# # URI of the parent class of all vernacualr description classes in the ontology.
	# VERNACULAR_ROOT = "http://aquarius.tw.rpi.edu/ontology/fungi.owl#FungusDescriptiveVernacular"
 #  # URI of the parent class of all feature classes in the ontology.
 #  FEATURE_ROOT = "http://aquarius.tw.rpi.edu/ontology/fungi.owl#hasFeature"

	# # Build a hierarchy of all vernacular descriptions and show them in html.
	# def build_vernacular_hierarchy(parent, tree)
	# 	ul = "<ul></ul>"
 #    if tree != nil
	# 		for i in 0..(tree.length - 1)
	# 			if tree[i]["parent"].to_s == parent
	# 				item = tree[i]
	# 				li = "<li>" << link_to(item["label"].to_s, 
	# 									             :controller => "semantic_vernacular", 
	# 															 :action => "show", 
	# 															 :uri => item["uri"].to_s) << "</li>"
	# 				subtree = build_vernacular_hierarchy(item["uri"].to_s, tree)
	# 				li.insert(-6, subtree) if subtree.gsub(/<ul><\/ul>/, "").length != 0
	# 				ul.insert(-6, li)
	# 			end
	# 		end
	# 	end
	# 	return ul
	# end

 #  # Build a hierarchy of all features and show them in html.
 #  def build_feature_hierarchy(parent, tree)
 #    ul = "<ul></ul>"
 #    if tree != nil
 #      for i in 0..(tree.length - 1)
 #        if tree[i]["parent"].to_s == parent
 #          item = tree[i]
 #          feature = SemanticFungalFeature.new(item["uri"].to_s)
 #          li = "<li>" << feature.label << "<span onclick=\"org.mo.sv.create.toggleFeatureValues('#{feature.uri}')\"> [+] </span><br />"
 #          li << "<select id=\"#{feature.uri}\" name=\"#{feature.label}\" multiple=\"multiple\" style=\"display:none;width:180px\">"
 #          feature.get_values.each do |value|
 #            li << "<option value=\"#{value["label"].to_s}\">#{value["label"].to_s}</option>"
 #          end
 #          li << "</select></li>"
 #          subtree = build_feature_hierarchy(feature.uri, tree)
 #          li.insert(-6, subtree) if subtree.gsub(/<ul><\/ul>/, "").length != 0
 #          ul.insert(-6, li)
 #        end
 #      end
 #    end
 #    return ul
 #  end
end
