class Crawler
	def self.version
		Gem::Version.new VERSION::STRING
	end
	module VERSION
		MAJOR =0
		MINOR =0
		TINY  =1
		PRE   =nil
		STRING = [MAJOR,MINOR,TINY,PRE].compact.join('.')
	end
end
