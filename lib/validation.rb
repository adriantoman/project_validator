require 'gooddata'
require 'json'
require 'faster_csv'
require 'archiver'


module ProjectValidator


  class Validation

      TASK_POOL_SIZE = 3

      attr_accessor :task_pool,:items_to_process, :login


      def initialize(login, password,items_to_process,export_path,server)
        @task_pool = Array.new
        @items_to_process = items_to_process
        @export_path = export_path
        @login = login
        GoodData.logger = Logger.new(STDOUT)
        GoodData.connect(login,password,server)

        check_server

      end


      def check_server
        json = get_acccessible_projects
        @items_to_process.delete_if do |item|
          delete = true
          json["about"]["links"].each do |project|
            #puts "Checking #{project["identifier"]}"
            if project["identifier"] == item.pid then delete = false end
          end
          delete
        end
      end


      def items_in_task_poll
        @task_pool.count
      end



      def get_acccessible_projects
        GoodData.connection.retryable(:tries => 3, :on => RestClient::InternalServerError) do
          sleep 5
          @response = GoodData.get("/gdc/md", :process => false)
        end
        JSON.parse @response
      end

      def check_user_access
        json =  get_acccessible_projects
        @items_to_process.each do |item|
          exist = false
          json["about"]["links"].each do |project|
            if project["identifier"] == item.pid then exist = true end
          end

            puts "User #{@login} don't have access to project #{item.customer}-#{item.project}(#{item.pid}) with responsible person #{item.responsible}" if exist != true
        end
      end


      def integration_running(pid)
        puts "Pid is: #{pid}"
        GoodData.use pid
        response = GoodData.project.check_status
        if (response =~ /RUNNING/) then
            puts "Project is RUNNING"
            return true
        else
            return false
        end
      end


      def start_validation(project_info)
        if (!integration_running(project_info.pid)) then
            GoodData.use project_info.pid
            pool_item = PoolItem.new(project_info,GoodData.project.validate)
            pool_item.start_time = DateTime.now
            @task_pool.push(pool_item)
          end
      end

      def check_status
        some_validation_finished = false
        while (!some_validation_finished)
          @task_pool.each do |item|
            item.refresh
            puts "Project #{item.pid} status is: #{item.is_done?}"
            if (item.is_done?) then some_validation_finished = true end
          end
          sleep(5) unless some_validation_finished
        end
      end


      def handle_finished_validation(pool_item)
          @task_pool.delete(pool_item)
          puts "Pid: #{pool_item.pid} was processed"
          pool_item.end_time = DateTime.now
          save_to_s3(pool_item.save_overview_information(@export_path))
          save_to_s3(pool_item.save_detail_information(@export_path))
          #File.open(pool_item.pid, 'w') {|f| f.write(JSON.pretty_generate(pool_item.json)) }
      end

      def handle_finished_validations
        @task_pool.find_all {|i| i.is_done?}.each do |item|
          handle_finished_validation(item)
        end
      end

      def process
        while (@items_to_process.count > 0 or items_in_task_poll > 0)
          while (items_in_task_poll < TASK_POOL_SIZE and @items_to_process.count > 0)
            start_validation(@items_to_process.pop)
          end
          check_status
          handle_finished_validations
        end
      end

      def save_to_s3(file_name)
          archiver = GDC::Archiver.new({
                                    :store_to_s3         => true,
                                    :logger              => GoodData.logger,
                                    :bucket_name         => "gooddata_com_gdc_validation"
                                })
          archiver.store_to_s3(Pathname.new(file_name))
      end



  #rescue RestClient::BadRequest => error
  #  puts error.inspect
  #  raise error
  #end
  #link = data["asyncTask"]["link"]["poll"]
  #response = GoodData.get(link, :process => false)
  #while response.code != 204
  #  sleep 10
  #  response = GoodData.get(link, :process => false)
  #end


  end


  class PoolItem
    attr_accessor :task_link,:response,:project_info,:json,:start_time,:end_time

    def initialize(project_info,link)
      @project_info = project_info
      @task_link = link
      @execution_id = /[^\/]*$/.match(@task_link)[0]
    end

    def pid
      @project_info.pid
    end

    def error_found
      @json["projectValidateResult"]["error_found"]
    end

    def fatal_error_found
      @json["projectValidateResult"]["fatal_error_found"]
    end

    def validation_result
      @json["projectValidateResult"]["results"]
    end


    def duration
      ((end_time - start_time) * 24 * 60 * 60).to_i
    end

    def refresh
      GoodData.connection.retryable(:tries => 3, :on => RestClient::InternalServerError) do
        sleep 5
        @response = GoodData.get(@task_link, :process => false)
      end
      parse
    end

    def is_done?
      if ((!@json["wTaskStatus"].nil?) and (@json["wTaskStatus"]["status"] == "RUNNING")) then
        return false
      else
        return true
      end
    end

    def parse
      @json = JSON.parse @response
    end


    def parse_log(log,level)
      count = 0
      if !log.nil? then
        log.each do |l|
          if l["level"] == level then
            count = count + 1
          end
        end
      end
      count
    end

    def save_overview_information(path)

      file_name = path + "pv_overview_#{@project_info.pid}_#{Date.today}.csv"
      FasterCSV.open(file_name, "w") do |csv|
        csv << ["id","error_found","pid","fatal_error_found","duration","date"]
        csv << [@execution_id,error_found,@project_info.pid,fatal_error_found,duration,end_time]
      end
      file_name
    end

    def save_detail_information(path)
      file_name = path + "pv_detail_#{@project_info.pid}_#{Date.today}.csv"
      FasterCSV.open(file_name, "w") do |csv|
        csv << ["id","section","errors","warnings"]
        elements = validation_result.group_by{|e| e["from"]}
        elements.each do |key,value|
          errors = 0
          warning = 0
          value.each do |v|
            errors = errors + parse_log(v["body"]["log"],"ERROR")
            warning = warning + parse_log(v["body"]["log"],"WARN")
          end
          csv << [@execution_id,key,errors,warning]
        end
      end
      file_name
    end


  end


end