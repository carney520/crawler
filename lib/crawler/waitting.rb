class Waiting
	def initialize(times,&b)
		@times=times
		@i=0
		raise ArgumentError,'condition not specify' unless block_given?
		@cond=b
		@sleeptime=1
	end

	def waiting
		while @cond.call and @i < @times
			#wait until @cond return false
			sleep(@sleeptime)
			@sleeptime*=2
			@i+=1
		end
		reset
	end

	def reset
		@i=0
		@sleeptime=1
	end
end
