class Artwork < ActiveRecord::Base
  def self.show_order_and_artwork_flow(trans_no)
    SalesOrder.find_by_sql ["select orderpickstatus_flag,orderentrycomplete_flag,orderacksent_flag,orderqcstatus_flag,accountreviewed_flag,
                                                artworkreceived_flag,artworkassigned_flag,artworkcompleted_flag,artwork_qc_assigned_flag,artworkreviewed_flag,artworksenttocust_flag,
                                                artworkapprovedbycust_flag from sales_orders
                                  where sales_orders.trans_no = ?",trans_no]
  end
end