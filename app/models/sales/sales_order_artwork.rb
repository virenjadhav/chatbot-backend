class Sales::SalesOrderArtwork < ActiveRecord::Base
  include UserStamp
  include Dbobject
  include GenericSelects
  include General
  #require 'win32ole'

  belongs_to :sales_order, :class_name => 'Sales::SalesOrder'
  #  validates_uniqueness_of :serial_no, :scope=>[:sales_order_id]
  #  followning before_save is commented for testing purpose subject to uncomment
  before_save :set_artwork_files, on: :create
  after_commit :move_artwork_files, on: :create
  #
  def schema_name
    ActiveRecord::Base.connection.current_database.upcase
  end

  def fill_default_detail_values
    #    path = Setup::Type.find_by_type_cd_and_subtype_cd('UPLOAD_FOLDER','ATTACHMENT')
    if self.new_record?
      path = Setup::Type.where("type_cd = ? and subtype_cd = ?",'UPLOAD_FOLDER','ATTACHMENT').first
      if path 
        directory = path.value + "#{schema_name}"
      end 
      self.artwork_file_path = File.join(directory, self.artwork_file_name)
    end
    if(self.new_record? == false and self.trans_flag == 'D' and self.trans_flag_was == 'A')
      Artwork::ArtworkProofLib.revert_proof_details(self)
    end
  end

  def set_artwork_files
    if self.new_record?
      path = Setup::Type.where(" type_cd = 'UPLOAD_FOLDER' and subtype_cd = 'ATTACHMENT' ").first
      begin
        if File.exists?("#{Dir.getwd}/#{self.artwork_file_path}")
          self.uploaded_file_size = ActiveSupport::NumberHelper.number_to_human_size(File.size("#{Dir.getwd}/#{self.artwork_file_path}")) 
        else
          archive_folder_path = Setup::Type.find_by_type_cd_and_subtype_cd('archive_folder','path').value
          final_artwork_file_full_name =  File.basename(self.artwork_file_name )
          artwork_archive_path  = "#{archive_folder_path}/#{schema_name}/#{self.sales_order.ref_trans_no}/#{final_artwork_file_full_name}"
          if File.exists?("#{artwork_archive_path}")
            self.uploaded_file_size = ActiveSupport::NumberHelper.number_to_human_size(File.size("#{artwork_archive_path}")) 
          end
        end
        if  self.proof_file_name.blank?
          self.proof_file_size  = ''
        else
          proof_file_path =  "#{Dir.getwd}/"+ path.value + "#{schema_name}/"+ self.proof_file_name
          file_size = ActiveSupport::NumberHelper.number_to_human_size(File.size("#{proof_file_path}"))
          self.proof_file_size = file_size    
        end 
      rescue Exception=> ex        
      end
      self.customer_id = self.sales_order.customer_id if self.customer_id.blank?
      if self.sales_order.trans_type == TRANS_TYPE_REORDER and !((self.artwork_file_name.split('/').last).blank?)
        self.artwork_file_name  = self.sales_order.trans_no + '/' + (self.artwork_file_name.split('/').last)
      else
        self.artwork_file_name  = self.sales_order.trans_no + '/' + self.artwork_file_name
      end
      unless self.proof_file_name.blank?
        if self.sales_order.trans_type == TRANS_TYPE_REORDER and !((self.artwork_file_name.split('/').last).blank?)
          self.proof_file_name  = self.sales_order.trans_no + '/' + (self.proof_file_name.split('/').last)
        else
          self.proof_file_name  = self.sales_order.trans_no + '/' + self.proof_file_name
        end
      end
      #self.artwork_file_path=   self.artwork_file_path[0..self.artwork_file_path.rindex("/")] + self.artwork_file_name
      self.artwork_file_path=   path.value + "#{schema_name}/" + self.artwork_file_name
    end
  end
  
  def move_artwork_files
    path = Setup::Type.where(" type_cd = 'UPLOAD_FOLDER' and subtype_cd = 'ATTACHMENT' ").first
    if path
      attachment_directory =  "#{Dir.getwd}/" + path.value + "#{schema_name}/"
    end
    destination_path = attachment_directory + self.sales_order.trans_no
    file_names = get_file_names
    source_path = attachment_directory 
    move_file_to_order_folder(source_path,destination_path,file_names, path) 
    if artwork_be_converted_to_png?
      file_name = File.basename(self.artwork_file_name)
      IO::FileIO.convert_file_to_png(file_name,schema_name,destination_path + '/')
    end
  end

  def get_file_names
    file_names = []
    file_names << self.artwork_file_name
    unless self.proof_file_name.blank?
      file_names << self.proof_file_name
    end
    if self.final_prodfile_flag == 'Y'
      file_names << self.artwork_file_name
    end
    return file_names
  end


  def artwork_be_converted_to_png?
    if self.sales_order.blank_order_flag == 'Y'
      return false
    elsif self.artwork_version  =~ (/#{DIGITIZED_ARTWORK}(.*)/)
      return false
    elsif (self.auto_proof_file_name.blank? and (self.final_artwork_flag == 'Y' or self.artwork_version  =~ (/(.*)#{VERSION_FILE}(.*)/)))
      return true
    elsif self.final_artwork_flag == 'Y'
      if self.final_artwork_flag_was == 'N'
        #old_artwork = Sales::SalesOrderArtwork.find_by_id(self.id)
        #if old_artwork.final_artwork_flag != 'Y' and self.final_artwork_flag == 'Y' and self.sales_order.paper_proof_flag != 'Y'
        return true
      end
      return false
    end
  end


  def move_file_to_order_folder(source_path,destination_path,file_names, path)
    FileUtils.mkdir_p(destination_path)
    new_file_name_ary = []
    file_names.each{|old_file|
      old_file_ary =  old_file.split('/')
      file_name_ary = old_file_ary[1].split('.')
      new_name = file_name_ary[0] +  "_" + Time.now.strftime('%m%d%Y%H%M%S') + "." + file_name_ary[1]
      if File.exists?(source_path + old_file_ary[1])
        File.rename(source_path + old_file_ary[1], source_path+new_name)
        FileUtils.cp source_path+File.basename(new_name), destination_path
      end
      new_file_name_ary << old_file_ary[0]+'/'+new_name
    }

    artwork = Sales::SalesOrderArtwork.find_by_id(self.id)
    # artwork.artwork_file_path = path.value+ new_file_name_ary[0]
    # artwork.artwork_file_name = new_file_name_ary[0]

    artwork.update_attributes!(:artwork_file_path =>  path.value+ new_file_name_ary[0],:artwork_file_name =>  new_file_name_ary[0]) 

    if file_names.length > 1
      # artwork.proof_file_name = new_file_name_ary[1]
      artwork.update_attributes!(:proof_file_name => new_file_name_ary[1]) 
    end
  end

  def add_line_errors_to_header
    
  end

  def self.set_proof_file_size(artwork,proof_file)
    if File.exists?("#{proof_file}")
      file_size = ActiveSupport::NumberHelper.number_to_human_size(File.size("#{proof_file}"))
      #      artwork.update_attribute(:proof_file_size ,file_size)   
      artwork.update_attributes!(:proof_file_size => file_size,:auto_proof_file_name => proof_file) 
    end
  end
  
end
