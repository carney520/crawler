class Heap
	def initialize(&b)
		if block_given?
			@b=b
		else
			@b=lambda{|child,parent| child <=> parent}
		end
		@heap=[]
		@left_child=lambda{|index| index*2+1}
		@right_child=lambda{|index| index*2+2}
		@parent=lambda{|index| (index-1)/2}
	end

	def pop
		lastindex=@heap.size-1	
		if lastindex < 0
			return nil
		elsif lastindex==0
			return @heap.shift
		end
		#swap first and last
		@heap[0],@heap[lastindex]=@heap[lastindex],@heap[0]
		first=@heap.pop

		#ajust heap
		index=0
		while true
			lindex=@left_child.call(index)
			rindex=@right_child.call(index)
			maxindex=nil

			if @heap[lindex].nil? and @heap[rindex].nil?
				break
			elsif @heap[lindex].nil?
				maxindex=	rindex
			elsif @heap[rindex].nil?
				maxindex= lindex
			else
				maxindex=@b.call(@heap[lindex],@heap[rindex])>0 ? lindex : rindex
			end
			#compare and swap
			if @b.call(@heap[index],@heap[maxindex]) < 0
				@heap[index],@heap[maxindex]=@heap[maxindex],@heap[index]
				index=maxindex
			else
				break
			end
		end
		first
	end

	def peer
		@heap.first
	end

	def <<(obj)
		@heap<<obj
		index=@heap.size-1
		#parent index
		pindex=@parent.call(index)
		return if index==0 #is root
		while pindex >= 0
			if @b.call(@heap[index],@heap[pindex]) > 0
				#swap child and parent
				@heap[index],@heap[pindex]=@heap[pindex],@heap[index]
				index=pindex
				pindex=@parent.call(index)
			else
				break
			end
		end
	end

	def take(num)
		raise ArgumentError,'Argument mush be a Fixnum' unless num.is_a? Fixnum
		result=[]
		until empty? or num <= 0
			result<< pop
		end
		result
	end

	alias_method :push,:<<
	def method_missing(method,*args,&b)
		if [:clear,:length,:size,:first,:empty?].include?(method)
			@heap.send(method,*args,&b)
		else
			super
		end
	end
end
