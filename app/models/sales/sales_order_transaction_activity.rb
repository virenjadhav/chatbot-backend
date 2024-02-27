class Sales::SalesOrderTransactionActivity < ActiveRecord::Base
  include UserStamp
  belongs_to :sales_order, :class_name => 'Sales::SalesOrder'
#  before_save do
##    self.user_id = self.updated_by
#  end

  def self.create_activity_message(order,activity_code)
    if !order.new_record?
      result = Sales::SalesOrderTransactionActivity.find_by_sql ["select count(*) as activity_count from sales_order_transaction_activities
                                                                  where sales_order_id=#{order.id} and trans_flag='A' and
                                                                  sales_order_stage_code like ?",activity_code+'%']
    end
    if result
      if result[0].activity_count.to_i == 0
        activity_code
      else
        return "#{activity_code} #{result[0].activity_count.to_i+1} TIMES"
      end
    else
      return activity_code
    end

  end
end
