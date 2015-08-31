module Consumer
	class Saver
		def save(title,text,metadata={keywords:'',description:'',date:''}) ; end
	end

	class FileSaver < Saver
		def initialize(save_dir=".")
			@save_dir=save_dir
		end

		def self.[](save_dir)
			return FileSaver.new(save_dir)
		end

		def save(title,text,metadata={keywords:'',description:'',date:''})
			File.open(File.join(@save_dir,title[0..15]+'.txt'),'w'){ |file|
				file.puts title
				file.puts metadata[:keywords],metadata[:date],metadata[:description]
				file.puts text
			}
		end
	end

	class RedisSaver < Saver
		def initialize(dbname,keyname)	
			@dbname,@keyname=dbname,keyname
		end

		def self.[](dbname,keyname)
			RedisSaver.new(dbname,keyname)
		end

		def save(title,text,metadata={keywords:'',description:'',date:''})
			#pending
		end
	end
end
