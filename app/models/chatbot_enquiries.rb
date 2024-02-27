class ChatbotEnquiries < ActiveRecord::Base
	def self.track_support_enquiries(trans_no)
		# @enquiries = ChatbotEnquiries.find_by_trans_no(trans_no)
		@enquiries = ChatbotEnquiries.find_by_sql("
select trans_no, enquiry_type, status, remark, estimation_completion_date, error_description, user_id, resolved, types.description as acknowledgement from chatbot_enquiries ce inner join types on (type_cd = 'chatbot' and subtype_cd = 'user_acknowledgement' and value = ce.user_acknowledgement) where ce.trans_no = #{trans_no} ")
		if @enquiries.blank?
			return nil, "error"
		else
			return @enquiries.first, "success"
		end
	end
end