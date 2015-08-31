#coding: utf-8
#version v8
#download with thread
#multi thread access unvisited queue and visited queue
require 'thread'
require 'mechanize'
require 'uri'
require 'thread'
require 'thwait'
require 'fileutils'
require 'logger'
require 'net/smtp'

Thread.abort_on_exception=true

trap('INT'){
	#logger cannot write in trap context
	$stderr.puts('exiting.............\n')
	exit 1
}

class Crawler
	VERSION = '0.0.1'
	attr_accessor :start_urls,
		:logger,
		:filters,
		:thread_limit,
		:delay,
		:encoding,
		:consumer_wait_queue_limit,
		:dbname,
		:consumer,
		#for email
		:enable_email,
		:email,
		:from,
		:address,
		:port,
		:domain,
		:username,
		:password,
		:authentication,
		:enable_ssl,
		:enable_starttls_auto

	def initialize(start_urls=[],            #Crawler entrances
								 filters={},          #urls filter
								 options={
									 thread_limit:1, #crawler thread limit
									 delay:0,
									 dbname:1,        #redis index
									 consumer_wait_queue_limit:1000, 
									 encoding:nil,    #default encoding
								 }
								)

		@start_urls=start_urls
		@filters=filters
		#the max Thread limit
		@thread_limit=        options[:thread_limit]
		@delay=       options[:delay]
		@encoding=            options[:encoding]
		@consumer_wait_queue_limit=options[:consumer_wait_queue_limit]
		@dbname=              options[:dbname]
		@consumer= Consumer::Parser.new()

		@logger=STDOUT

		#for email
		@enable_email=false
		@email=''
		@from=@email
		@address='localhost'
		@port=25
		@domain='localhost'
		@username=''
		@password=''
		@authentication='plain'
		@enable_ssl=false
		@enable_starttls_auto=true

		yield self if block_given?
		#initialize logger
		$logger=Logger.new(@logger)
		$logger.datetime_format="%Y:%m:%m %H:%M:%S"
		$logger.formatter=proc{|serverity,datetime,programname,msg|
			"[#{datetime}]-[#{serverity}]-#{msg}"
		}



		$logger.info("[Crawler] : Initializing Crawler...\n")

		#ensure the consumer dbname according to crawler
		@consumer.dbname=@dbname

		#check option here
		raise ArgumentError,'start_urls is empty' if @start_urls.empty?

		@frontier=Crawler::Frontier.new(@dbname)

		filter=LinkFilter.new(@filters[:allow],@filters[:deny])
		@frontier.filter_compile(filter)
		$logger.info("[Crawler] : Compiled filters...\n")


		#initial a thread group with include download threads
		@tg=ThreadGroup.new

		@start_urls.each{|uri|
			@frontier.push(uri)
		}

		if @frontier.empty?
			$logger.fatal("[Crawler] : Initial url illegal\n")
			$stderr.puts "initial url illegal!\n"
			exit(-1)
		end

		@finished=0
		@producter=Consumer::Product.new(@dbname)

	end

	def	add_links(page)
		page.links.each do |link|
			begin
				uri=URI(link.href)
				absolute_link=uri.host.nil? ? URI.join(page.uri.to_s,link.href) : uri
			rescue URI::InvalidURIError
				next
			end
			@frontier.push(absolute_link)
		end
	end

	def add_finished
		@finished_mutex ||=Mutex.new
		@finished_mutex.synchronize{
			@finished=@finished.succ
		}
	end

	def start
		#@start_time=Time.now
		@agent=Mechanize.new{|a|
			a.robots=true
			a.keep_alive=false
			a.user_agent_alias='Mac Safari'
			#a.gzip_enabled=true
			a.max_history=1
		}

		#fork a sub process to consume the resource
		@childproc = fork do
			$logger.info("[Crawler] : Fork a subprocess to consum the fetch results\n")
			begin
				@consumer.start
			rescue
				#down the process
				puts $!.class,$!.message,$!.backtrace
				Process.kill('INT',Process.ppid)
				exit(-1)
			end
		end

		#wait if @frontier.empty
		waiting=Waiting.new(6) {@frontier.empty?}

		until @frontier.empty?
			#a Thread sliding window
			#@tg.list.first.join if @tg.list.size >=30
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
			puts "((((((((((((((((((((#{@tg.list.size}))))))))))))))))))))"
			
			begin
				t=Thread.new do
					#when empty the Array would not block
					crawler_link=@frontier.shift
					#check if visited
					Thread.exit if crawler_link.nil? || @frontier.visited?(crawler_link)
						agent=@agent
					offline_retry_count=0
					begin
						#clone the agent so they in one session
						page=agent.get(crawler_link,[],nil,{'Host'=>crawler_link.host})
						page.encoding=@encoding unless @encoding.nil?
					rescue Mechanize::RobotsDisallowedError
						$logger.info("[Crawler] : Rotbots disallow:#{crawler_link.to_s}\n")
						Thread.exit
					rescue Mechanize::ResponseCodeError
						case $!.response_code
						when '202' then
							#the request non finish,block to read
							sleep 1
							retry
						else
							$logger.warn("[Crawler] : Abandon [#{$!.response_code}]-#{crawler_link.to_s[0..36]+'...'}\n")
							Thread.exit
						end
					rescue SocketError
						#the network break up
						offline_retry_count+=1
						if offline_retry_count == 3
							down($!)
						else
							retry
						end
					rescue 
						#exit when error raised
						$logger.warn("[Crawler] : Error(#{$!.class}:#{$!.message}) raised when access #{crawler_link.to_s}\n")
						Thread.exit
					ensure
						@frontier.visited(crawler_link)
					end

					Thread.exit unless page.instance_of? Mechanize::Page
					add_links(page)

					#push page for consumer
					#we can't push the page directly
					#because it can't dump by YAML
					@producter.push(Consumer::Page.new(page))
					$logger.info("[Crawler] : Visited: #{crawler_link.to_s} #{page.title}\n")
					add_finished
				end
			rescue ThreadError
				sleep 1
				retry
			end

			@tg.add(t)
			#if empty sleep 1 sec waiting Thread to add new links
			#if there is no more unvisited link,it will stop in next loop
			sleep @delay
			waiting.waiting
			#Set a limit to the Consumers Queue
			sleep 1 while @producter.size > @consumer_wait_queue_limit
		end
		@agent.shutdown
		#join all unfinished threads
		@tg.list.each{|th| th.join}
		#until all source been consumed
		until @producter.empty?
			sleep 1
		end
		Process.wait(@childproc)

		#print total
		puts "Total    :   #{Time.now-@start_time}"
		puts "dealed   :   #{@finished}"
		puts "Unvisited:   #{@frontier.unvisits_size}"
		puts "Visited  :   #{@frontier.visiteds_size}"
		$logger.info "[Crawler]:dealed   :   #{@finished}\n"
		$logger.info "[Crawler]:Total    :   #{Time.now-@start_time}\n"
		$logger.info "[Crawler]:Unvisited:   #{@frontier.unvisits_size}\n"
		$logger.info "[Crawler]:Visited  :   #{@frontier.visiteds_size}\n"
	rescue
		down($!)
	ensure
		$logger.close
	end

	def down(err)
		message="#{err.class}\n#{err.message}\n#{err.backtrace.join("\n")}"
		$logger.fatal "[Crawler] crawler down #{message}"
		#kill the subprocess
		#log the down reason and notify Aderministrater

		body=<<BODY
From: crawler <#{@from}>
To: #{@email}
Subject: Crawler was down!

ErrorClass      : #{err.class}
------------------------------
ErrorMessage    : #{err.message}
------------------------------
ErrorBacktrace  : 
#{err.backtrace.join("\n")}
------------------------------
ErrorRaisedTime : #{Time.now.to_s}
BODY

		if @enable_email
			#send email to the aderministrator
			Net::SMTP.start(@address,@port,@domain,@username,@password,@authentication)	do |smtp|
				smtp.enable_ssl if @enable_ssl
				smtp.enable_starttls_auto if @enable_starttls_auto
				smtp.send_mail(body,@from,@email)
			end
		end
		Process.kill('INT',@childproc)
	rescue
		puts $!.class,$!.message,$!.backtrace.join("\n")
	ensure
		exit(-1)
	end
end

require 'crawler/waitting'
require 'crawler/frontier'
require 'crawler/consumer/consumer'

=begin
Crawler.new do |crawler|
	crawler.start_urls=['http://667vv.com','http://667vv.com/AAtb/zipai/']
	crawler.filters={
		allow:{
			#'host'=>{
			#'/path'=>'query'
			#}
			'http://667vv.com'=>{
				#allow 'http://677vv.com' and 'http://677vv.com/'
				'/'=>nil,
				#allow 'http://677vv.com/AAtb/zipai[/*]'
				'/AAtb/zipai'=>nil,
				#allow 'http://677vv.com/AAwz[/*]'
				'/AAwz'=>nil
			}
		},
		deny:{
		}
	}
	crawler.thread_limit=1
	crawler.delay=0
	crawler.dbname=1
	crawler.encoding=nil
	crawler.consumer_wait_queue_limit=100


	#when the crawler is down send a mail to administrator
	crawler.enable_email=true
	#the administrator's email address
	crawler.email='carney520@hotmail.com'
	crawler.from='920432773@qq.com'  #the email-address which same as the authentic user
	crawler.address='smtp.qq.com'
	crawler.port=25
	crawler.username='920432773'
	crawler.password='kwiqealy8976'
	crawler.enable_starttls_auto=true

	consumer=crawler.consumer
	consumer.thread_limit=1
	consumer.delay=0
	save_dir='/home/pi/share/toupai'
	consumer.task={
		#global consumer
		'.'=>nil,
		#host name
		'667vv.com'=>{
			#path
			'/AAwz'=>proc do |page|
				#article extrator
				#saver=Consumer::FileSaver.new('/home/pi/share')
				#Consumer::Article.new(page).saveto(saver).consume

				save_formatter = proc do |uri,title,filename,extname,index|
					#uri  : the page uri
					#title: the page title
					#filename: the source native filename.note that it included extname 
					#					such as 'asdacada123asdad.jpg'
					#extname: the resource extname
					#index  : a uniq index
					#we should return a string and ensure the string a legal for file save
					#by default it return a string like "#{title[0..15]}/filename"
					File.join("#{Time.now.strftime("%Y%m%d")}","#{title[0..15]}","#{index.to_s+extname}")
				end

				#images download
				imagedownload=Consumer::Images.new(page).saveto(save_dir).select(/^\/uploads/).enable_thumbnail
				imagedownload.formatter=save_formatter
				imagedownload.consume
			end
		}
	}
end.start
=end
