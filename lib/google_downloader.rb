require "google_drive"


module ProjectValidator


  class GoogleDownloader


    attr_accessor :session, :spredsheet, :worksheet,:projects


    def initialize(login,password,spredsheet,worksheet)
      @session = GoogleDrive.login(login, password)
      @projects = Array.new

      download_spredsheet_by_id(spredsheet)
      set_worksheet(worksheet)
      load_projects
    end


    def download_spredsheet_by_id(id)
      @spredsheet = session.spreadsheet_by_key(id)
    end

    def set_worksheet(index)
        @worksheet = @spredsheet.worksheets[index]
    end


    def load_projects
      project_col = get_column_id("Project")
      customer_col = get_column_id("Customer")
      pid_col = get_column_id("Project pid")
      status_col = get_column_id("Status")
      validation_col = get_column_id("Automatic validation")


      for row in 2..@worksheet.num_rows
          project_info = ProjectInfo.new(@worksheet[row,customer_col],@worksheet[row,project_col],@worksheet[row,pid_col],@worksheet[row,status_col],@worksheet[row, validation_col])
          @projects.push(project_info)
      end
    end

    def get_column_id(name)
      for col in 1..@worksheet.num_cols
         pp @worksheet[1,col]
          if (@worksheet[1,col] == name) then
            return col
          end
      end
    end

    def get_projects_to_validate
      @projects.find_all{|project| project.validate? }
    end

  end


  class ProjectInfo

    attr_accessor :customer, :project, :pid, :status, :validate

   def initialize(customer,project,pid, status,validate)
      @customer = customer
      @project = project
      @pid = pid
      @status = status
      @validate = validate

    end

    def validate?
      if (validate.downcase == "yes") then
        return true
      else
        return false
      end
    end



  end


end