# encoding: utf-8
#
#  = Semantic Vernacular Data Source
#
#  This class is a sub class of SemanticVernacularDataSource class. Method "query" is
#  overridden to retrieve data through the RPI SparqlProxy web service.
#
#  == Class Methods
#  === Private
#  query:: 												Submit a query and get responses.
#
################################################################################

class SemanticVernacularDataSourceViaProxy < SemanticVernacularDataSource
	private
	
	RPI_SPARQLPROXY = "http://logd.tw.rpi.edu/ws/sparqlproxy.php"
	QUERY_OUTPUT_FORMAT = "exhibit"	# json

	# Retrun value is in the format of
	# [{key => value}, {key => value}, ... ]
	def self.query(query)
		url = URI.parse(
						RPI_SPARQLPROXY + 
						"?query=" + URI.encode_www_form_component(query) + 
						"&service-uri=" + URI.encode_www_form_component(ENDPOINT) + 
						"&output=" + URI.encode_www_form_component(QUERY_OUTPUT_FORMAT)
					)
		http = Net::HTTP.new(url.host, url.port)
		request = Net::HTTP::Get.new(url.request_uri)
		response = JSON.parse(http.request(request).body)["items"]
	end
end