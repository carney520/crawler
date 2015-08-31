require 'redis'
require 'yaml'
require 'thread'
require 'thwait'
require 'crawler/consumer/delegate'
require 'crawler/waitting'

#for page analyse and download source
#comsumer close by parent process
module Consumer

	#product for parent process
	class Product
		def initialize(dbname=1,listname='pagelist')
			@db=Redis.new
			@db.select(dbname)
			@listname=listname
			@mutex=Mutex.new
		end

		def push(obj)
			@mutex.synchronize{
				@db.rpush(@listname,YAML.dump(obj))
			}
		end

		def size
			@db.llen(@listname)
		end
		#when empty the parent will kill the subprocess
		def empty?
			size == 0
		end
	end
	
	#comsume for Parser
	class Consume
		def initialize(dbname=1,listname='pagelist')
			@db=Redis.new
			@db.select(dbname)
			@listname=listname
			@mutex=Mutex.new
		end

		def size
			@db.llen(@listname)
		end

		def empty?
			size == 0
		end

		#block if empty
		def shift
			@mutex.synchronize{
				#timeout for 30sec
				a=@db.lpop(@listname)
				return nil if a.nil?
				YAML.load(a)
			}
		rescue
			nil
		end
	end

	class Parser
		attr_accessor :dbname,
			:thread_limit,
			:delay,
			:task

		def initialize(options={dbname:1,thread_limit:1,delay:0})
			@dbname=      options[:dbname]
			@thread_limit=options[:thread_limit]
			@delay=       options[:delay]
			@task={}
			yield self if block_given?
			@tg=ThreadGroup.new
			trap('INT'){puts "consumer exiting";exit 1}
		end

		def start
			@list=Consume.new(@dbname)
			@delegator=Delegate.new(@task)
			#wait 5 time if @list.empty? 
			waiting=Waiting.new(6) {@list.empty?}
			waiting.waiting
			until @list.empty? 
				page=@list.shift
				while @tg.list.size > @thread_limit
					begin
						ThreadsWait.all_waits(@tg.list) do
							#break if any thread finished
							break
						end
					rescue ThreadError
						sleep 1
					end
				end

				begin
					t=Thread.new do
						#yield page
						@delegator.action(page)
					end
				rescue ThreadError
					sleep 1
					retry
				end
				@tg.add(t)
				sleep @delay
				waiting.waiting
			end

			@tg.list.each{
				|th|
				th.join
			}
		end
	end
end
