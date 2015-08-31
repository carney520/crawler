require 'crawler/consumer/articleextractor'
require 'crawler/consumer/saver'

module Consumer
	class Article
		def initialize(page)
			@page=page.clone
			@extractor=ArticleExtractor.new(page.content)
			@saver=nil
		end

		def saveto(saver)
			raise ArgumentError unless saver.is_a? Saver
			@saver=saver
			self
		end

		def consume
			@extractor.preprocess
			#check if a article website
			if @extractor.linkdensity > 0.7 
				return
			end

			text=@extractor.extract
			if @saver
				title=@extractor.title
				date=@extractor.date
				description=@extractor.description
				keywords=@extractor.keywords
				@saver.save(@extractor.title,text,:date=>date,:description=>description,:keywords=>keywords)
				$logger.info "[Consumer] Saved article:#{title}\n"
			end
		end
	end
end
