require 'fiber'
require 'thread'
require 'crawler/heap'

=begin example

d =Download.new
0.upto(10) do |i|
	d.add do |t|
		#asyncronous call task
		#and return yield
		result=d.task{
			sleep 1
			i
		}

		#when task finished,exec next
		p "finished: #{result}"
	end
end
d.scheduler

=end

class Job
	attr_reader :job,:priority
	def initialize(priority=1,&b)
		raise Exception,"block non-exist" unless block_given?
		@job=b
		@priority=priority
	end
end

class Download
	def initialize(thread_limit=4)
		@eventqueue=Heap.new{|l,r| l.priority <=> r.priority}
		@threadgroup=ThreadGroup.new
		@thread_limit=thread_limit
	end

	def exec(task)
		Fiber.new do
			task.call
		end.resume
	end


	def scheduler
		until @threadgroup.list.empty? && @eventqueue.empty?
			task=@eventqueue.pop
			if task.nil?
				sleep 1
				next
			else
				exec(task.job)
			end
		end
	end

	def task(priority=1,&b)
		raise Exception,"block non-exist" unless block_given?
		f=Fiber.current
		while threads_count >= @thread_limit
			sleep 1
		end
		begin
			t=Thread.new do
				Thread.current[:name]='task'
				result=b.call
				job=Job.new(priority){f.resume result}
				@eventqueue.push(job)
			end
		rescue ThreadError
			sleep 1
			retry
		end
		@threadgroup.add(t)
		return Fiber.yield
	end

	def add(priority=2,&b)
		raise Exception,"block non-exist" unless block_given?
		@eventqueue.push(Job.new(priority,&b))
		self
	end

	private
	def threads_count
		@tgmutex||=Mutex.new
		@tgmutex.synchronize{
			@threadgroup.list.size
		}
	end
end

=begin

require 'uri'
require 'mechanize'
Thread.abort_on_exception=true
d=Download.new
j=Mechanize.new
j.pluggable_parser['image']=Mechanize::Download
p=j.get('http://www.lu42.com/article/?17749.html')

p.image_urls.select{ |link|
	link.path.start_with? '/pic/upload'
}.each do |url|
	d.add do
		p url
		download=d.task do
			a=j.clone
			begin	
				puts "getting #{url.to_s}"
				a.get(URI.decode(url.to_s))
			rescue 
				puts "error #{$!.class}"
				nil
			end
		end
		unless download.nil?
				download.save('/home/pi/share/toupai/'+download.filename+'.jpg')
				puts "saved!"
		end
	end
end

d.scheduler



def get(d)
	f=Fiber.current
	Thread.new{
		sleep 1
		d<<proc{
			f.resume 9
		}
		puts "task finished"
	}
	return Fiber.yield
end

d=Download.new
#the task will be execed in Fiber context
d<< proc{
	#asyncronous call get(d)
	#and return yield
	result=get(d)
	#when task finished,exec next
	puts "daad #{result}"
}
d.scheduler
sleep 2
d.scheduler
=end
