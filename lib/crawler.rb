#coding: utf-8
require 'thread'
require 'mechanize'
require 'uri'
require 'thread'
require 'thwait'
require 'fileutils'
require 'logger'
require 'net/smtp'
$:.unshift(File.expand_path('..',__FILE__))

Thread.abort_on_exception=true

trap('INT'){
  #logger cannot write in trap context
  $stderr.puts('exiting.............\n')
  exit 1
}

class Crawler
  instance_eval{
    def writable(*sym)
      sym.each do |s|
        define_method s.to_s do |data|
          instance_variable_set "@#{s.to_s}",data
        end
      end
    end
  }
  writable :start_urls,        #crawler entrances
    :logger,                        #the path to save the logger,it defalut to STDOUT
    :loglevel,                      #set logger level: UNKNOWN < FATAL < ERROR < WARN < INFO < DEBUG,it default to 'Logger::INFO'
    :filters,                        #the urls filters
    :thread_limit,                  #the Crawler thread limit
    :delay,                          #specify how long to start next request
    :encoding,                      #the website encoding,the default is nil.
    :consumer_wait_queue_limit,     #when the Consumer queue size great the this threshold,the Crawler will sleep 
    :dbname,                        #the Redis database index
    #for email
    :enable_email,                  #enable the email,if some problems led to the Crawler down,it will send a email to you
    :to,                          #recipient's email
    :from,                          #sender's email
    :address,                        #the SMTP server ip address or hostname,the default is 'localhost'
    :port,                          #the SMTP server port, the default is 25
    :domain,                        #the HELO domain provided by the client to the server,to default to 'localhost'
    :username,                      #the SMTP authentication account name
    :password,                      #the SMTP authentication password
    :authentication,                #the authentication type, one of :plain,:login,:cram_md5
    :enable_starttls_auto,           #enables SMTP/TLS(STARTTLS)
    :enable_ssl                      #enables SMTP/TLS(SMTPS:SMTP over direct TLS connection)
    #Mechanize Agent

  def initialize(start_urls=[],            #Crawler entrances
                 filters={},          #urls filter
                 options={
                   thread_limit:1, #crawler thread limit
                   delay:0,
                   dbname:1,        #redis index
                   consumer_wait_queue_limit:200, 
                   encoding:nil,    #default encoding
                 },
                 &block
                )

    @start_urls=start_urls
    @filters=filters
    #the max Thread limit
    @thread_limit=        options[:thread_limit]
    @delay=               options[:delay]
    @encoding=            options[:encoding]
    @consumer_wait_queue_limit=options[:consumer_wait_queue_limit]
    @dbname=              options[:dbname]
    @consumer= Consumer::Parser.new()

    @logger=STDOUT
    @loglevel=Logger::INFO

    #for email
    @enable_email=false
    @to=''
    @from=@to
    @address='localhost'
    @port=25
    @domain='localhost'
    @username=nil
    @password=nil
    @authentication=:login
    @enable_starttls_auto=true
    @enable_ssl=false

    #mechanize agent
    @agent=Crawler::Agent.instance

    instance_eval(&block) if block_given?

    #initialize logger
    $logger=Logger.new(@logger)
    $logger.level=@loglevel
    $logger.datetime_format="%Y:%m:%m %H:%M:%S"
    $logger.formatter=proc{|serverity,datetime,programname,msg|
      "[#{datetime}]-[#{serverity}]-#{msg}"
    }



    $logger.info("[Crawler] Initializing Crawler...\n")

    #ensure the consumer dbname according to crawler
    @consumer.dbname=@dbname

    #check out option here
    raise ArgumentError,'start_urls is empty' if @start_urls.empty?

    @frontier=Crawler::Frontier.new(@dbname)

    filter=LinkFilter.new(@filters[:allow],@filters[:deny])
    @frontier.filter_compile(filter)
    $logger.info("[Crawler] Compiled filters...\n")


    #initial a thread group with include crawler threads
    @tg=ThreadGroup.new

    @start_urls.each{|uri|
      @frontier.push(uri)
    }

    if @frontier.empty?
      $logger.fatal("[Crawler] start urls illegal\n")
      exit(-1)
    end
  
    #create a Mechanize agent  
    $logger.info("[Crawler] start session\n")
    @agent.keep_alive=false
    #a.gzip_enabled=true
    @agent.max_history=1

    @finished=0
    @producter=Consumer::Product.new(@dbname)

  end

  def agent(&block)
    yield @agent if block_given?
    @agent
  end

  def consumer
    yield @consumer if block_given?
    @consumer
  end

  def enable_email(&block)
    @enable_email=true
    instance_eval(&block) if block_given?
  end


  def add_links(page)
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
    @start_time=Time.now

    #fork a sub process to consume the resource
    @childproc = fork do
      $logger.info("[Crawler] Fork a Consumer\n")
      begin
        @consumer.start
      rescue
        #down the process
        $logger.fatal("[Crawler] Consumer down!(#{$!.class}:#{$!.message}):\n#{$!.backtrace.join("\n")}\n")
        #kill parent
        Process.kill('INT',Process.ppid)
        self.down($!)
        exit(-1)
      end
    end

    #wait if @frontier.empty
    waiting=Waiting.new(6) {@frontier.empty?}

    until @frontier.empty?
      #a Thread sliding window
      while @tg.list.size >= @thread_limit
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
          $logger.debug("[Crawler] Fork a thread(#{@tg.list.size})\n")
          #when empty the Array would not block
          crawler_link=@frontier.shift
          #check if visited
          Thread.exit if crawler_link.nil? || @frontier.visited?(crawler_link)
          begin
            #clone the agent so they in one session
            page=@agent.get(crawler_link,Mechanize::Page,[],nil,{'Host'=>crawler_link.host})
            page.encoding=@encoding unless @encoding.nil? || page.nil?
          rescue OfflineError
            #network off-line
            down($!)
          ensure
            @frontier.visited(crawler_link)
          end

          Thread.exit unless page
          add_links(page)
          #push page for consumer
          #we can't push the page directly
          #because it can't dump by YAML
          @producter.push(Consumer::Page.new(page))
          $logger.info("[Crawler] Visited #{crawler_link.to_s} #{page.title}\n")
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
    #all done,now we shutdown the Mechanize agent
    #join all unfinished threads
    @tg.list.each{|th| th.join}
    #until all source been consumed
    until @producter.empty?
      sleep 1
    end
    #and join the Consumer
    Process.wait(@childproc)
    @agent.shutdown

    #print statistic
    $logger.info "[Crawler] dealed   :   #{@finished}\n"
    $logger.info "[Crawler] Total    :   #{Time.now-@start_time}\n"
    $logger.info "[Crawler] Unvisited:   #{@frontier.unvisits_size}\n"
    $logger.info "[Crawler] Visited  :   #{@frontier.visiteds_size}\n"
  rescue
    down($!)
  ensure
    $logger.close
    self
  end





  def down(err)
    message="#{err.class}\n#{err.message}\n#{err.backtrace.join("\n")}"
    $logger.fatal "[Crawler] crawler down #{message}\n"
    #kill the subprocess
    #log the down reason and notify Aderministrater

body=<<BODY
From: crawler <#{@from}>
To: #{@to}
Subject: Crawler was down!

ErrorClass      : #{err.class}
------------------------------
ErrorMessage    : #{err.message}
------------------------------
ErrorBacktrace  : 
    #{err.backtrace.map{|str| "\t\t"+str.to_s}.join("\n")}
------------------------------
ErrorRaisedTime : #{Time.now.to_s}
BODY

    if @enable_email
      #send email to the aderministrator
      Net::SMTP.start(@address,@port,@domain,@username,@password,@authentication)  do |smtp|
        smtp.enable_starttls_auto if @enable_starttls_auto
        smtp.enable_ssl if @enable_ssl
        smtp.send_mail(body,@from,@to)
      end
    end
    Process.kill('INT',@childproc) if @childproc
  rescue
    puts $!.class,$!.message,$!.backtrace.join("\n")
  ensure
    exit(-1)
  end


  def clear!
    #clear unvisits queue and visiteds queue from Redis
    @frontier.clear!
  end
end

require 'crawler/agent'
require 'crawler/exception'
require 'crawler/waitting'
require 'crawler/frontier'
require 'crawler/consumer/consumer'
