require 'mechanize'
require 'crawler/frontier'
module Consumer
	class Page
		attr_accessor :uri, #web uri
			:title, #web title
			:links, #an array of links
			:images, #an array of images
			:content, #a native conten
			:encoding  #the page encoding

		def initialize(page)
			#argument page is an instance of Mechanize::Page
			raise TypeError unless page.is_a? Mechanize::Page
			@uri=Crawler::Frontier.uri_compile(page.uri)
			@title=page.title
			@content=page.parser.to_s
			@encoding=page.encoding

			parse_url=lambda do |uri|
				begin
					uri=URI(uri) unless uri.is_a? URI
				#check if a relative url
					uri=uri.host.nil? ? URI.join(@uri.to_s,uri.to_s) : uri
					uri=Crawler::Frontier.uri_compile(uri)
				rescue URI::InvalidURIError
					next nil
				rescue ArgumentError
					next nil
				end
			end

			@links=[]
			@images=[]

			page.images.each{|image|
				begin
					#there may raise a URI::InvalidURIError if image.url not a legal format
					url=parse_url.call(image.url)
				rescue URI::InvalidURIError
					next
				end
				next if url.nil?
				img={}
				img[:url]=url
				img[:alt]=image.alt
				img[:title]=image.title
				img[:mime_type]=image.mime_type
				img[:extname]=image.extname
				@images<<img
			}

			page.links.each{|link|
				begin
					url=parse_url.call(link.uri)
				rescue URI::InvalidURIError
					next
				end
				next if url.nil?
				uri={}
				uri[:url]=url
				uri[:text]=link.text
				@links<<uri
			}
		end
	end
end
