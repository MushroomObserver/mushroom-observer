module SemanticVernacularHelper
	# URI of the parent class of all the vernacualr classes.
	ROOT = "http://aquarius.tw.rpi.edu/ontology/mushroom.owl#FungusDescriptiveVernacular"

	# Build a hierarchy of all vernaculars and show them in html.
	def build_vernacular_hierarchy(parent, tree)
		if tree != nil
			ul = "<ul>"
			for i in 0..(tree.length - 1)
				if tree[i]["parent"] == parent
					item = tree[i]
					li = "<li>" << link_to(item["label"], :controller => "semantic_vernacular", :action => "show", :uri => item["uri"])
					subtree = build_vernacular_hierarchy(item["uri"], tree)
					li << subtree if subtree != nil
					li << "</li>"
					ul << li << "</ul>"
				end
			end
		end
		return ul
	end
end
