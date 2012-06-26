module SemanticVernacularHelper
	# URI of the parent class of all vernacualr classes.
	ROOT = "http://aquarius.tw.rpi.edu/ontology/fungi.owl#FungusDescriptiveVernacular"

	# Build a hierarchy of all vernaculars and show them in html.
	def build_vernacular_hierarchy(parent, tree)
		if tree != nil
			ul = "<ul>"
			for i in 0..(tree.length - 1)
				if tree[i]["parent"].to_s == parent
					item = tree[i]
					li = "<li>" << link_to(item["label"].to_s, 
																 :controller => "semantic_vernacular", 
																 :action => "show_vernacular", 
																 :uri => item["uri"].to_s)
					subtree = build_vernacular_hierarchy(item["uri"].to_s, tree)
					li << subtree if subtree != nil
					li << "</li>"
					ul << li << "</ul>"
				end
			end
		end
		return ul
	end
end
