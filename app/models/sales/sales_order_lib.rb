class Sales::SalesOrderLib
  # include General

  # def self.create_cancel_orders(doc)
  #   sales_orders = [] 
  #   (doc/:sales_orders/:sales_order).each{|order_doc|
  #     sales_order = create_cancel_order(order_doc)
  #     sales_orders <<  sales_order if sales_order
  #   }
  #   sales_orders
  # end
  
  def self.create_cancel_order(trans_no, order_cancellation_reason)
    begin
      #emails = []; result = 'success'; message = 'success'
      # binding.pry
      # trans_no =  (order_doc/'trans_no').inner_text if (order_doc/'trans_no').inner_text
      # order_id =  (order_doc/'id').inner_text if (order_doc/'id').inner_text
      # cancel_order_reason =  (order_doc/'cancel_order_reason').inner_text if (order_doc/'cancel_order_reason').inner_text
 
      order = SalesOrder.find_by_trans_no_and_trans_flag("#{trans_no}", 'A')
      return nil, 'error', 'order# is not valid'  if !order
      return nil, 'error', 'Order is already Cancelled' if order.ordercancelstatus_flag == 'Y'
      # order.lock_version = parse_xml(order_doc/'lock_version').to_i if (order_doc/'lock_version').first
      #clear_qty is made equal to item_qty in case of order cancellation
      order.clear_qty = order.item_qty
      # binding.pry
      # sales_order_lines = order.sales_order_lines.select{|line| line.trans_flag == 'A'}
      # binding.pry
      # sales_order_lines.each{|line|
      #   line.clear_qty = line.item_qty
      # }
      # binding.pry
      # sub_orders = Sales::SalesOrder.find_all_by_sub_ref_no_and_trans_flag("#{order.trans_no}",'A')
      # sub_orders = Sales::SalesOrder.where("sub_ref_no='#{order.trans_no}' and trans_flag = 'A'")
      # # binding.pry
      # if !sub_orders.blank?
      #   sub_orders.each{|sub_order|
      #     sub_order.ordercancelstatus_flag = 'Y';sub_order.salt = '';sub_order.artwork_salt = '';
      #     sub_order.cancel_date = Time.now; sub_order.order_status = ORDER_CLOSED;
      #     sub_order.update_flag = 'V'; sub_order.workflow_location = 'ORDER CLOSED'; sub_order.cancel_order_reason = cancel_order_reason;
      #     sub_order.create_sales_order_transaction_activity(ORDER_CANCELLED)
      #   }
      # end
      order.update(:ordercancelstatus_flag => 'Y', :cancel_date => Time.now, :order_status => 'ORDER CLOSED', :update_flag => 'V', :workflow_location => 'ORDER CLOSED',
          :cancel_order_reason => order_cancellation_reason)
      # if(order.errors.empty?)
      #   order.save!
      # end
      enquiry, result, message = generate_enquiry_ticket(order, 'Cancel Order')
      if(result=='error')
        return nil, 'error', message
      end
      return enquiry, 'success', 'Order Cancelled'
    rescue Exception => ex
      return nil, 'error', ex.to_s
    end
    return nil, 'error', ''
  end

  def self.generate_enquiry_ticket(order, reason)
    begin 
    enquiry = ChatbotEnquiries.new
    max_trans_no = ChatbotEnquiries.find_by_sql("select max(trans_no) as trans_no  from chatbot_enquiries").first.trans_no
    # binding.pry
    enquiry_type = reason == 'Cancel Order'? 'Cancel Order' : 'Hold Order'
    enquiry.trans_flag = 'A'
    enquiry.trans_no = max_trans_no.to_i + 1
    enquiry.lock_version = 0
    enquiry.enquiry_type = enquiry_type
    enquiry.status = 'Complete'
    enquiry.user_acknowledgement = 4
    enquiry.remark = order.cancel_order_reason
    enquiry.estimation_completion_date = Time.now()
    enquiry.error_description = ''
    enquiry.user_id = 1
    enquiry.request_json = ''
    enquiry.resolved = 'Y'
    enquiry.save!
    rescue Exception => ex
      return nil, 'error', ex.to_s
    end
    return enquiry, 'success', ex.to_s
  end

  def self.order_on_hold(trans_no, user_id, hold_order_reason)
    # msg = ''
    # trans_no = (doc/:order_doc/'trans_no').inner_text if (doc/:order_doc/'trans_no').inner_text
    # hold_order_reason = (doc/:order_doc/'hold_order_reason').inner_text if (doc/:order_doc/'hold_order_reason').inner_text
    # user_id = (doc/:order_doc/'user_id').inner_text if (doc/:order_doc/'user_id').inner_text
    # order = Sales::SalesOrder.where("trans_no = '#{trans_no}' and trans_flag = 'A'")
    order = SalesOrder.find_by_trans_no_and_trans_flag(trans_no, 'A')
    # if (order[0].blank?)
    #   msg = "Order doesn't exist!!"
    #   return msg
    # end
    # if order[0].hold_order_flag == 'N' 
    #   user_name = Admin::User.where(id: user_id)
    #   begin
    #     order.update( :hold_by => user_name[0]['first_name'], :hold_order_flag => 'Y', :hold_order_reason => hold_order_reason)
    #   binding.pry
    #     order[0].create_sales_order_transaction_activity("ORDER IS PUT ON HOLD")
    #     order[0].save!
    #   rescue Exception => ex
    #     return ex,'error'
    #   end
    #   msg = "Order is put on hold!!"
    # else 
    #   msg = "Order is already On Hold!!"
    #   # order.create_sales_order_transaction_activity("ORDER IS TAKEN OFF HOLD")
    # end
    return nil, 'error', 'Order # is not valid' if !order 
    return nil, 'error', 'Order is already On Hold!!' if order.hold_order_flag == 'Y'
    user_name = User.where(id: user_id)
    begin
    order.update( :hold_by => user_name[0]['first_name'], :hold_order_flag => 'Y', :hold_order_reason => hold_order_reason)
      enquiry, result, message = generate_enquiry_ticket(order, 'Hold Order')
      if(result=='error')
        return nil, 'error', message
      end
      return enquiry, 'success', 'Order is put on hold!!'
      rescue Exception => ex
        return nil, 'error', ex.to_s
      end
    return nil, 'error', ''
  end

#   def self.generate_order_acknowledgement(sales_order,send_to_email,schema_name,flag)
#     begin
#       absolute_filename = Sales::PrawnFormats::OrderAcknowledgement.generate_order_acknowledgement(sales_order,schema_name)
#       if flag == true
#         sales_order.corr_dept_email = send_to_email
#         email = Email::Email.send_email('ORDERACKNOWLEDGMENT',sales_order)
#         email.attachment_file = absolute_filename
#         #        email.save!
#         activity_message = Sales::SalesOrderTransactionActivity.create_activity_message(sales_order,'ORDER ACKNOWLEDGMENT RE-SENT')
#         activity = sales_order.create_sales_order_transaction_activity(activity_message)
#         activity.save!
#       end
#       #      return true,absolute_filename
#       return true,absolute_filename,email
#     rescue Exception => ex
#       return false,ex,nil
#     end
#   end

#   ## function which reassignes order to other user from quality check screen
#   def self.reassign_order_to_other_user(doc,order)
#     orderassignedtouser_id =  parse_xml(doc/'orderassignedtouser_id') if (doc/'orderassignedtouser_id').first
#     orderassignedtouser_code =  parse_xml(doc/'orderassignedtouser_code') if (doc/'orderassignedtouser_code').first
#     if (!order.new_record? and order.orderreassigned_flag == 'Y' and order.orderentrycomplete_flag == 'Y' and order.orderqcstatus_flag == 'N')
#       order.orderassignedtouser_code = orderassignedtouser_code ; order.orderassignedtouser_id = orderassignedtouser_id
#       order.order_status = ORDER_REASSIGNED_FOR_ENTRY ; order.orderentrycomplete_flag = 'N'
#       order.orderqcstatus_flag = 'N'
#       activity_message = Sales::SalesOrderTransactionActivity.create_activity_message(order,"ORDER REASSIGNED TO : #{orderassignedtouser_code} FOR ENTRY")
#       order.create_sales_order_transaction_activity(activity_message)
#     end
#   end
    
#   #this function is not in use dec2015
#   def self.get_orders_pending_amount(customer_id)
#     pending_orders = Sales::SalesOrder.find_all_by_customer_id_and_invoiced_flag(customer_id,'N')
#     order_amount = 0.00
#     pending_orders.each{|pending_order|
#       order_amount = order_amount + nulltozero(pending_order.net_amt)
#     }
#     return order_amount
#   end

#   def self.create_customer_shippings(doc,order)
#     customer_shippings = []
#     (doc/:sales_order_shippings/:sales_order_shipping).each{|shipping|
#       customer_shipping_id =  parse_xml(shipping/'customer_shipping_id') if (shipping/'customer_shipping_id').first
#       if (!customer_shipping_id || customer_shipping_id == '')
#         customer_shipping,text = Customer::CustomerCrud.create_customer_shippings(shipping,order)
#         if text == 'error'
#           break
#         else
#           customer_shippings << customer_shipping
#         end
#       end
#     }
#     customer_shippings
#   end


#   ## Used In REORDER screen to fetch shipped orders fetch by id and trans no(when order is quick reorder then trans_no is used bcos id is not available)
#   def self.show_shipped_order_dtls(order_id,trans_no)
#     #if (order_id and order_id != 'null')
#     if (!order_id.blank? and order_id != 'null')
#       Sales::SalesOrder.find_all_by_id(order_id)
#       #elsif(trans_no and trans_no != 'null')
#     elsif(!trans_no.blank? and trans_no != 'null' )
#       Sales::SalesOrder.find_all_by_trans_no(trans_no)
#     end
#   end
#   ## PickOrder Services ##
#   def self.list_pick_orders(doc)
#     criteria = Setup::Criteria.fill_criteria_for_query(doc/:criteria)
#     #changes from sql to sp calling
#     list = ActiveRecord::Base.connection.select_all("exec sp_promo_list_pick_order '#{criteria.user_id}','#{OI_PICK}'")
#      list
 
#   end

#   # this service is called from controllers to remove queries from views
#   def self.fetch_order_details(order_id)
#     sales_order = Sales::SalesOrder.find_by_sql("select * from sales_orders where id = #{order_id}")[0]

#     customer_parent = Customer::Customer.find_by_sql ["select cust.*, prnt.code as parent_code,prnt.name as parent_name
#                                                  from customers cust left outer join customers prnt
#                                                 on cust.billto_code = prnt.code where cust.code = '#{sales_order.customer_code}'"]

#     note_count = Setup::NoteCrud.get_note_count('sales_order',sales_order.id) if sales_order.id

#     attachment_count = Setup::AttachmentCrud.get_attachment_count('sales_order',sales_order.id) if sales_order.id

#     #Chaitanya 21-02-2023 added this to prevent an additional service call on retrive record

#     customer_contacts = fetch_customer_contact(sales_order.customer_id,sales_order.customer_contact) if sales_order.id

#     customer_logins = Admin::User.find_by_sql ["select users.*,user_companies.id as user_company_id,(u.first_name + ' ' + u.last_name) as created_by_user,
#                                                 case isnull(users.customer_role,'')
#                                                     when 'A' then 'Admin'
#                                                     when 'B' then 'Supervisor'
#                                                     when 'C' then 'User'
#                                                     else '' end 
#                                                   as user_level 
#                                                 from users 
#                                                 inner join  user_companies on (users.id = user_companies.user_id)
#                                                 left outer join users u on (users.created_by = u.id)
#                                                 where  user_companies.trans_flag = 'A' and users.type_id = '#{sales_order.customer_id}' and users.login_type = 'C'
#                                                 order by user_cd  "] if sales_order.id
#     #------------------------------------------------------------------------------------------
#     sales_order_artworks = fetch_order_artworks(sales_order.id)

#     #        sales_order_transaction_activities = Sales::SalesOrderTransactionActivity.find_by_sql("
#     #        select (users.first_name + ' ' + users.last_name + ' (' + types.description + ')') as user_name,users.email as user_email,sota.activity_date,
#     #        sota.sales_order_stage_code,sota.duration
#     #        from sales_order_transaction_activities  sota
#     #        left outer join users on users.id = sota.user_id and users.trans_flag = 'A'
#     #        left outer join types on (
#     #                                        types.type_cd = 'login_type'
#     #                                        and types.subtype_cd = 'login_type'
#     #                                        and users.login_type = types.value
#     #                                       )
#     #        where sota.trans_flag = 'A' and sota.sales_order_id = #{sales_order.id}
#     #        order by sota.activity_date desc")

#     ##    sales_order_shippings = Sales::SalesOrderShipping.find_by_sql ["select * from sales_order_shippings where trans_flag = 'A'
#     #                                                                    and sales_order_id = #{sales_order.id}#"]
#     sales_order_shippings = fetch_sales_order_shippings(sales_order.id)
#     shipping_import_remark = ''
#     sales_order_shippings.each{|sales_order_shipping| shipping_import_remark = shipping_import_remark + "#{sales_order_shipping.shipping_import_remark}"}

#     sales_order_shipments = fetch_sales_order_shipments(sales_order.id)


#     #    purchase_orders = Purchase::PurchaseOrder.find_by_sql ("select trans_no from purchase_orders where trans_flag = 'A' and trans_type = 'S'
#     #                                                              and ref_trans_no = '#{sales_order.trans_no}'#")

#     # purchase_orders = Purchase::PurchaseOrder.find_by_sql ("select po.trans_no from purchase_orders po
#     #                                                         inner join sales_orders so on so.po_no = po.trans_no
#     #                                                         where po.trans_flag = 'A' and po.trans_type = 'S' and so.trans_flag ='A'
#     #                                                         and so.trans_no = '#{sales_order.trans_no}'")


#     purchase_orders = []
#  purchase_orders = Purchase::PurchaseOrder.find_by_sql ("select po.trans_no from purchase_orders po
                                                           
#                                                             where po.trans_flag = 'A' and po.trans_type = 'S' and
#                                                              po.trans_no = '#{sales_order.po_no}'")  if sales_order.po_no
                                                            

#     ##    sales_invoices = Sales::SalesInvoice.find_by_sql ["select si.id,si.trans_date,si.trans_no,users.first_name as created_by_user,ci.paid_amt,ci.inv_amt from sales_invoices si inner join customer_invoices ci  on
#     #                                                      (si.trans_bk=ci.trans_bk and si.trans_no =ci.trans_no and si.trans_date= ci.trans_date)
#     #                                                       inner join users on si.created_by = users.id  where si.ref_trans_no = '#{sales_order.trans_no}'#"]

#     #Sales invoices find logic changed to below to show invoices in case of terms e.g. 50D-30D
#     sales_invoices = fetch_sales_invoices(sales_order.trans_no)
#    sales_order_discount_coupons =[]
#     sales_order_discount_coupons =  Setup::DiscountCoupon.find_by_sql("select * from discount_coupons where trans_flag = 'A'
#                                                                          and coupon_code = '#{sales_order.coupon_code}'") if sales_order.coupon_code

#     sales_order_attributes_values = fetch_order_attributes_values(sales_order.id)

#     sales_order_catalog_lines = fetch_order_catalog_line(sales_order.id)

#     discount_coupon_count = Setup::DiscountCoupon.find_by_sql("select COUNT(*) as count from discount_coupons where customer_id = #{sales_order.customer.id} AND
#                                                             trans_flag ='A' AND ((no_of_uses - no_of_used) <> 0) AND approval_flag = 'Y' AND
#                                                            (CONVERT(date,GETDATE(),101) between CONVERT(date,from_date,101) and CONVERT(date,to_date,101))") if sales_order.customer
#     #sales_order_threads = Sales::SalesOrderThread.find_by_sql("select * from sales_order_threads where trans_flag = 'A' and sales_order_id = #{sales_order.id}")

#     ##    if sales_order.sub_ref_type == REF_TYPE_MAIN_ORDER
#     ##      sub_orders = Sales::SalesOrder.find_by_sql("select  count(*) as count, sum(item_qty) as total_sub_order_qty from sales_orders where trans_flag= 'A' and    
#     #                                                sub_ref_no = '#{sales_order.trans_no}' group by  sub_ref_no#")
#     ##      
#     ##    else
#     ##      sub_orders = Sales::SalesOrder.find_by_sql("select  count(*) as count, sum(item_qty) as total_sub_order_qty from sales_orders where trans_flag= 'A' and
#     #                                                  sub_ref_no = '#{sales_order.sub_ref_no}' group by  sub_ref_no#")
#     #      
#     #      main_order =  Sales::SalesOrder.find_by_trans_no_and_trans_flag(sales_order.sub_ref_no,'A')
#     #    end
        
#     sub_orders = fetch_sub_orders(sales_order)
#     sub_order_count = sub_orders.first.count if sub_orders.first    
#     sub_order_total_qty = sub_orders.first.total_sub_order_qty if sub_orders.first
#     main_order =  Sales::SalesOrder.find_by_trans_no_and_trans_flag(sales_order.sub_ref_no,'A') if sales_order.sub_ref_type == REF_TYPE_SUB_ORDER
#     main_order_qty = main_order.item_qty if main_order

#     catalog_item_code = sales_order_catalog_lines.blank? ? '' : sales_order_catalog_lines.first.catalog_item_code
#     ##    sales_order_lines = Sales::SalesOrderLine.find_by_sql(" select * from
#     #                                                            (select sales_order_lines.*,ci.unit,ci.taxable,ci.image_thumnail,ci.has_expired_date_flag,ci.name as catalog_item_name
#     #                                                             from sales_order_lines
#     #                                                             left outer join catalog_items ci on ci.id = sales_order_lines.catalog_item_id
#     #                                                             where sales_order_lines.trans_flag = 'A' and sales_order_id = #{sales_order.id}) line_items
#     #                                                             left outer join
#     #                                                            (select cav.invn_item_code,cav.code as option_value from catalog_items ci
#     #                                                             inner join catalog_item_attributes_values ciav
#     #                                                              on ci.id = ciav.catalog_item_id
#     #                                                              inner join catalog_attribute_values cav
#     #                                                             on ciav.catalog_attribute_value_id = cav.id
#     #                                                              where ci.store_code = '#{catalog_item_code}'
#     #                                                               and ci.trans_flag = 'A' and ciav.trans_flag = 'A' and cav.trans_flag = 'A'
#     #                                                               and cav.invn_item_code is  not null and cav.invn_item_code <> '') linked_items
#     #                                                               on line_items.catalog_item_code = linked_items.invn_item_code #")
    
#     sales_order_lines = fetch_sales_order_lines(sales_order.id)
    
#     #setup_catalog_item = Item::CatalogItem.find_by_store_code(SETUP_CHARGE_SETUP_ITEM_CODE)
#     setup_catalog_item = Item::CatalogItem.select("id").where("store_code = ?",SETUP_CHARGE_SETUP_ITEM_CODE).first
       
#     #secondlocationcharge_catalog_item = Item::CatalogItem.find_by_store_code(SECOND_LOCATION_CHARGE_SETUP_ITEM_CODE)
#      secondlocationcharge_catalog_item = Item::CatalogItem.select("id").where("store_code = ?",SECOND_LOCATION_CHARGE_SETUP_ITEM_CODE).first

#     #thirdpartyshippingcharge_catalog_item = Item::CatalogItem.find_by_store_code(THIRD_PARTY_SHIPPING_CHARGE_SETUP_ITEM_CODE)
#     thirdpartyshippingcharge_catalog_item = Item::CatalogItem.select("id").where("store_code = ?",THIRD_PARTY_SHIPPING_CHARGE_SETUP_ITEM_CODE).first

#     #multi_shipment_location_charge_catalog_item = Item::CatalogItem.find_by_store_code(MULTI_SHIPMENT_LOCATION_CHARGE_SETUP_ITEM_CODE)
#     multi_shipment_location_charge_catalog_item = Item::CatalogItem.select("id").where("store_code = ?",MULTI_SHIPMENT_LOCATION_CHARGE_SETUP_ITEM_CODE).first

#     #rushday1_charge_catalog_item = Item::CatalogItem.find_by_store_code(RUSHDAY1_SETUP_ITEM_CODE)
#     rushday1_charge_catalog_item = Item::CatalogItem.select("id").where("store_code = ?",RUSHDAY1_SETUP_ITEM_CODE).first

#     #rushday2_charge_catalog_item = Item::CatalogItem.find_by_store_code(RUSHDAY2_SETUP_ITEM_CODE)
#     rushday2_charge_catalog_item = Item::CatalogItem.select("id").where("store_code = ?",RUSHDAY2_SETUP_ITEM_CODE).first

#     sales_quotation_line = Quotation::SalesQuotationLine.find_by_id(sales_order.ref_virtual_line_id)

#     customer_card_transactions =  fetch_customer_card_transactions(sales_order.id,sales_order.trans_no,sales_order.trans_bk)

#     preproduction_charge = Sales::SalesOrderLine.active.where("catalog_item_code = '#{PREPRODUCTION_CHARGE_SETUP_ITEM_CODE}'")
#    # preproduction_charge_catalog_item = Item::CatalogItem.find_by_store_code(PREPRODUCTION_CHARGE_SETUP_ITEM_CODE)
#     preproduction_charge_catalog_item = Item::CatalogItem.select("id").where("store_code = ?",PREPRODUCTION_CHARGE_SETUP_ITEM_CODE).first
  
#     sales_order_queries = fetch_order_queries(order_id)
#     #sales_order_purchases = Sales::SalesOrderPurchase.find_by_sql("select * from sales_order_purchases sop left join purchase_orders po on (sop.purchase_order_id=po.id AND po.trans_flag='A' AND sop.trans_flag='A')  WHERE sop.sales_order_id='#{sales_order.id}' ")
#     sales_order_locations = Sales::SalesOrderLocation.find_by_sql("select id,location_code,catalog_item_code,item_qty,trans_flag,expiry_date from sales_order_locations   WHERE sales_order_locations.sales_order_id='#{sales_order.id}' and sales_order_locations.trans_flag='A' ")

#     order_details = Hash.new
#     order_details[:sales_order_artworks] = sales_order_artworks
#     order_details [:customer_parent] = customer_parent
#     order_details [:customer_contacts] = customer_contacts
#     order_details [:customer_logins] = customer_logins
#     #order_details[:sales_order_transaction_activities] = sales_order_transaction_activities
#     order_details[:sales_invoices] = sales_invoices
#     order_details[:note_count] = note_count
#     order_details[:attachment_count] = attachment_count
#     order_details[:sales_order_shippings] = sales_order_shippings
#     order_details[:sales_order_shipments] = sales_order_shipments
#     order_details[:purchase_orders] = purchase_orders
#     order_details[:sales_order_catalog_lines] = sales_order_catalog_lines
#     order_details[:sales_order_attributes_values] = sales_order_attributes_values
#     order_details[:sales_order_discount_coupons] = sales_order_discount_coupons
#     order_details[:sales_order_lines] = sales_order_lines
#     order_details[:sub_order_count] = sub_order_count
#     order_details[:sub_order_total_qty] = sub_order_total_qty
#     order_details[:main_order_qty] = main_order_qty    
#     order_details[:discount_coupon_count] = discount_coupon_count
#     order_details[:setup_catalog_item] = setup_catalog_item
#     order_details[:secondlocationcharge_catalog_item] = secondlocationcharge_catalog_item
#     order_details[:thirdpartyshippingcharge_catalog_item] = thirdpartyshippingcharge_catalog_item
#     order_details[:sales_quotation_line] = sales_quotation_line
#     order_details[:multi_shipment_location_charge_catalog_item] = multi_shipment_location_charge_catalog_item
#     order_details[:preproduction_charge] = preproduction_charge
#     order_details[:preproduction_charge_catalog_item] = preproduction_charge_catalog_item
#     order_details[:customer_card_transactions] = customer_card_transactions
#     order_details[:rushday1_charge_catalog_item] = rushday1_charge_catalog_item
#     order_details[:rushday2_charge_catalog_item] = rushday2_charge_catalog_item
#     #order_details[:sales_order_threads] = sales_order_threads 
#     order_details[:shipping_import_remark] = shipping_import_remark
#     order_details[:queries] = sales_order_queries
#     #order_details[:sales_order_purchases] = sales_order_purchases
#     order_details[:sales_order_locations] = sales_order_locations
#     order_details
#   end

#   #############-----promo customer portal services ------#########

#   def self.show_sales_order_proofs(salt)
#     Sales::SalesOrder.find_by_artwork_salt(salt)
#   end

#   ##this function is not in use dec 2015
#   ##  def self.is_invoiced_amount_received?(receipt)
#   ##    customer_receipt_lines = Customer::CustomerReceiptLine.find_by_sql("select * from customer_receipt_lines where trans_no = '#{receipt.trans_no}' order by ref_no")
#   ##    customer_receipt_lines.each{|receipt_line|
#   ##      sales_invoices = Sales::SalesInvoice.find_by_sql("select * from sales_invoices where trans_no = '#{receipt_line.ref_no}'")
#   ##      sales_invoices.each{|sales_invoice|
#   ##        order_invoiced_amount = Sales::SalesInvoice.find_by_sql("select sum(net_amt) as net_amt from sales_invoices where trans_flag = 'A' and ref_trans_no = '#{sales_invoice.ref_trans_no}' ")
#   ##        order_received_amount = Customer::CustomerReceiptLine.find_by_sql("select sum(apply_amt) as applied_amt from customer_receipt_lines
#   #                                where ref_no in (select trans_no from sales_invoices where ref_trans_no = '#{sales_invoice.ref_trans_no}') and apply_flag = 'Y'#")
#   #        if order_invoiced_amount.first.net_amt == order_received_amount.first.applied_amt
#   #          sales_order = Sales::SalesOrder.find_by_trans_no("#{sales_invoice.ref_trans_no}")
#   #          sales_order.update_attributes!(:order_status => ORDER_CLOSED,:workflow_location => ORDER_CLOSED) if sales_order.order_status == INVOICED
#   #        end
#   #      }
#   #    }
#   #  end

#   # NOT IN USE ----- This method is used on order screen to fetch Qty_on_sales_orders
#   def self.get_qty_on_sales_orders(catalog_item_code)
#     sales_orders = Sales::SalesOrder.find_by_sql("select isnull((SUM(sales_order_lines.item_qty)-SUM(sales_order_lines.clear_qty)),0.00) as open_so_qty from sales_orders inner join sales_order_lines
#                                                   on sales_orders.id = sales_order_lines.sales_order_id
#                                                   where sales_orders.trans_flag = 'A' and sales_order_lines.trans_flag = 'A'
#                                                   AND sales_orders.ordercancelstatus_flag <> 'N' and sales_orders.artworkapprovedbycust_flag <> 'N'
#                                                   AND sales_orders.order_status <> 'ORDER CLOSED' and sales_orders.trans_type NOT IN ('#{TRANS_TYPE_VIRTUAL_ORDER}')
#                                                   AND sales_order_lines.item_type = '#{INVENTORY}' and sales_order_lines.item_qty > sales_order_lines.clear_qty
#                                                   AND sales_order_lines.catalog_item_code = #{catalog_item_code}")
#     qty_on_sales_orders = sales_orders.first.open_so_qty
#     return qty_on_sales_orders
#   end

#   def self.open_orders(doc)
#     catalog_item_code  = parse_xml(doc/:params/'catalog_item_code')
#     # Sales::SalesOrder.find_by_sql ["select distinct sales_orders.trans_no,sales_orders.ext_ref_no,sales_orders.trans_date,sales_order_lines.catalog_item_code,sales_orders.order_status,sales_order_lines.item_qty,
#     #                                    sales_orders.trans_type as ref_type FROM sales_orders
#     #                                    INNER JOIN sales_order_lines ON sales_order_lines.sales_order_id = sales_orders.id
#     #                                    WHERE sales_orders.trans_flag = 'A' AND sales_orders.sub_ref_type = '#{REF_TYPE_MAIN_ORDER}'
#     #                                    And sales_order_lines.item_qty > sales_order_lines.clear_qty AND sales_orders.order_status <> 'ORDER CLOSED' AND sales_orders.order_status <> 'INVOICED'
#     #                                    AND sales_orders.ordercancelstatus_flag <> 'Y' AND sales_orders.trans_type <> '#{TRANS_TYPE_VIRTUAL_ORDER}' and sales_order_lines.trans_flag = 'A'
#     #                                    AND sales_order_lines.catalog_item_code= '#{catalog_item_code}'"]
#     Sales::SalesOrder.find_by_sql ["select  sales_orders.trans_no,sales_orders.ext_ref_no,sales_orders.trans_date,sales_order_lines.catalog_item_code,sales_orders.order_status,sales_order_lines.item_qty,
#                                        sales_orders.trans_type as ref_type FROM sales_orders
#                                        INNER JOIN sales_order_lines ON sales_order_lines.sales_order_id = sales_orders.id
#                                        WHERE sales_orders.trans_flag = 'A' AND sales_orders.sub_ref_type = '#{REF_TYPE_MAIN_ORDER}'
#                                        And sales_order_lines.item_qty > sales_order_lines.clear_qty AND sales_orders.order_status <> 'ORDER CLOSED' AND sales_orders.order_status <> 'INVOICED'
#                                        AND sales_orders.ordercancelstatus_flag <> 'Y' AND sales_orders.trans_type <> '#{TRANS_TYPE_VIRTUAL_ORDER}' and sales_order_lines.trans_flag = 'A'
#                                        AND sales_order_lines.catalog_item_code= '#{catalog_item_code}'"]

#   end

#   def self.resend_ack_email_and_make_activity(order,pdf_file_name_path)
#     email = Email::Email.send_email('ORDERACKNOWLEDGMENT',order)
#     email.attachment_file = pdf_file_name_path
#     activity_message = Sales::SalesOrderTransactionActivity.create_activity_message(order,'ORDER ACKNOWLEDGMENT RE-SENT')
#     order.create_sales_order_transaction_activity(activity_message)
#     return email
#   end

#   def self.is_item_changed(order)
#     order.sales_order_lines.select{|sol| sol.item_type == CATALOG}.each{|item_line|
#       order.create_sales_order_transaction_activity("CATALOG ITEM #{item_line.catalog_item_code} IS REMOVED") if item_line.trans_flag == 'D' and item_line.trans_flag_changed?
#       return
#     }
#   end
  
#   def self.create_manual_price_change_activity(doc,order)
#     item_price_edited =  parse_xml(doc/'item_price_edited') if (doc/'item_price_edited').first
#     if (item_price_edited == 'Y')
#       order.sales_order_lines.select{|sol| sol.item_type == CATALOG and sol.trans_flag == 'A'}.each{|item_line|
#         edited_price = item_line.item_price
#         if(item_line.new_record?)
#           original_price = item_line.item_master_price
#         else
#           original_price = item_line.item_price_was
#         end
#         order.create_sales_order_transaction_activity("ITEM PRICE CHANGED MANUALLY FROM (#{original_price}) TO (#{edited_price})") 
#       }
#     end
#     return
#   end
    
#   def self.is_po_or_artwork_removed(order)
#     order.sales_order_artworks.select{|sol| sol.trans_flag == 'D' and sol.trans_flag_changed?}.each{|artwork|
#       if order.trans_type == TRANS_TYPE_REORDER
#         order.create_sales_order_transaction_activity("#{artwork.artwork_version} IS CHANGED/REMOVED")
#       else
#         order.create_sales_order_transaction_activity("#{artwork.artwork_version} IS REMOVED")
#       end
#     }
#   end

#   def self.is_setup_charge_removed(order)
#     order.sales_order_lines.select{|sol| sol.item_type == SETUP  and sol.is_manually_added == 'Y'}.each{|sales_order_line|
#       if  sales_order_line.new_record?
#         activity_message = "SETUP CHARGE #{sales_order_line.catalog_item_code} IS ADDED"
#         order.create_sales_order_transaction_activity(activity_message)
#       elsif sales_order_line.trans_flag == 'D' and sales_order_line.trans_flag_changed? #to make activity for currently deleted entry
#         activity_message = "SETUP CHARGE #{sales_order_line.catalog_item_code} IS REMOVED"
#         order.create_sales_order_transaction_activity(activity_message)
#       end
#     }
#   end

#   def self.set_shipping_reference(sales_order)
#     sales_order.sales_order_shippings.select{|sos| sos.trans_flag == 'A'}.each{|shipping|
#       shipping.ship_ref1 = sales_order.ext_ref_no if shipping.ship_ref1.blank?
#       shipping.ship_ref2 = "#{sales_order.trans_no} / #{sales_order.customer_code}" if shipping.ship_ref2.blank?
#     }
#   end
  
#   def self.move_order_to_new_customer(order_code,from_customer,to_customer,user_id)
#     begin
#       ActiveRecord::Base.connection.select_all("exec sp_move_order_to_new_customers
#              '#{from_customer}',    '#{to_customer}',   '#{order_code}', '#{user_id}'")
#       return 'Customer Changed Successfully',true
#     rescue Exception=>ex
#       return ex.to_s,false
#     end
#   end
  
#   def self.fetch_order_catalog_line(order_id)
#     Sales::SalesOrderLine.find_by_sql ["select * from sales_order_lines where trans_flag = 'A' and item_type = '#{CATALOG}'
#                                                             and line_type = '#{CATALOG_LINE_TYPE}' and sales_order_id = #{order_id}"]
#   end
  
#   def self.fetch_order_artworks(order_id)  
#     Sales::SalesOrderArtwork.find_by_sql("select * from sales_order_artworks where trans_flag = 'A' and sales_order_id = #{order_id}")
#   end
  
#   def self.fetch_customer_contact(customer_id,customer_contact)
#       first_name = customer_contact.split(" ")[0]
#       last_name = customer_contact.split(" ")[1]
#       customer_contacts = Customer::CustomerContact.find_by_sql ["select id, LTRIM(RTRIM((isnull(first_name,'')+' '+isnull(last_name,'')))) as contact_name,address1,address2,city,state,zip,country,fax,business_phone,manager_phone,home_phone,cell_phone,email from customer_contacts where trans_flag = 'A' and  first_name = isnull(?,'') and last_name = isnull(?,'') 
#                                                                   and customer_id = ?",first_name,last_name,customer_id]
#       return customer_contacts
#   end

#   def self.fetch_order_attributes_values(order_id)
#     Sales::SalesOrderAttributesValue.find_by_sql ["select * from sales_order_attributes_values where trans_flag = 'A' and sales_order_id = #{order_id}"]
#   end
  
#   def self.fetch_sub_orders(order)
#     if order.sub_ref_type == REF_TYPE_MAIN_ORDER
#       Sales::SalesOrder.find_by_sql("select  count(*) as count, sum(item_qty) as total_sub_order_qty from sales_orders where trans_flag= 'A' and    
#                                                 sub_ref_no = '#{order.trans_no}' group by  sub_ref_no")
      
#     else
#       Sales::SalesOrder.find_by_sql("select  count(*) as count, sum(item_qty) as total_sub_order_qty from sales_orders where trans_flag= 'A' and
#                                                   sub_ref_no = '#{order.sub_ref_no}' group by  sub_ref_no")            
#     end 
#   end
  
#   def self.fetch_sub_order_count(order)
#     sub_orders = fetch_sub_orders(order)
#     if sub_orders.first
#       sub_orders.first.count 
#     else
#       0
#     end
#   end

#   def self.fetch_total_sub_order_qty(order)
#     sub_orders = fetch_sub_orders(order)
#     if sub_orders.first
#       sub_orders.first.total_sub_order_qty 
#     else
#       0
#     end
#   end
  
#   def self.fetch_sales_order_shippings(order_id)
#     Sales::SalesOrderShipping.includes(:sales_order_shipping_packages,:sales_order_shipments).find_all_by_sales_order_id_and_trans_flag(order_id,'A')
#   end
  
#   def self.fetch_sales_order_lines(order_id)
#     Sales::SalesOrderLine.find_by_sql("select * from (
#                                                            select sales_order_lines.*,ci.unit,ci.taxable,ci.image_thumnail,ci.has_expired_date_flag,ci.name as catalog_item_name 
#                                                            from sales_order_lines 
#                                                            left outer join catalog_items ci on ci.id = sales_order_lines.catalog_item_id 
#                                                            where sales_order_lines.trans_flag = 'A' and sales_order_lines.sales_order_id = #{order_id}) line_items 
#                                                            left outer join 
#                                                            (select cav.invn_item_code,soav.catalog_attribute_value_code as option_value,ca.code as option_code 
#                                                            from sales_order_lines sol,sales_order_attributes_values soav,catalog_attributes ca, catalog_attribute_values cav 
#                                                            where sol.sales_order_id = soav.sales_order_id and sol.sales_order_id= #{order_id}
#                                                            and sol.item_type='#{CATALOG}' and soav.catalog_attribute_code = ca.code and ca.id = cav.catalog_attribute_id 
#                                                            and soav.catalog_attribute_value_code = cav.code and isnull(invn_item_code,'') <> '' 
#                                                            and sol.trans_flag = 'A' and soav.trans_flag = 'A' and cav.trans_flag = 'A'
#                                                            union
#                                                            select  cav.invn_item_code,soamv.value as option_value ,ca.code as option_code
#                                                            from sales_order_lines sol,sales_order_attributes_values soav,catalog_attributes ca, catalog_attribute_values cav,
#                                                            sales_order_attributes_multiple_values soamv 
#                                                            where sol.sales_order_id = soav.sales_order_id and  soav.id =  soamv.sales_order_attributes_value_id
#                                                            and sol.sales_order_id= #{order_id}
#                                                            and sol.item_type='#{CATALOG}' and soav.catalog_attribute_code = ca.code and ca.id = cav.catalog_attribute_id 
#                                                            and  soamv.value = cav.code and isnull(invn_item_code,'') <> '' 
#                                                            and sol.trans_flag = 'A' and soav.trans_flag = 'A' and cav.trans_flag = 'A'
#                                                            and soamv.trans_flag = 'A' and soamv.qty >0
#                                                            ) linked_items
#                                                            on line_items.catalog_item_code = linked_items.invn_item_code")
#   end
  
#   def self.fetch_sales_order_shipments(order_id)
#     Sales::SalesOrderShipment.find_by_sql ["select * from sales_order_shipments where trans_flag = 'A' and sales_order_id = #{order_id}"]  
#   end

#   def self.fetch_sales_invoices(order_trans_no)
#     Sales::SalesInvoice.find_by_sql ["select si.id,si.trans_date,si.trans_no,users.first_name as created_by_user,
#                                                        (select sum(ci.paid_amt) from customer_invoices ci where main_trans_no = si.trans_no and si.trans_bk=ci.trans_bk and si.trans_date= ci.trans_date) as paid_amt,
#                                                        (select sum(ci.inv_amt) as inv_amt from customer_invoices ci where main_trans_no = si.trans_no  and si.trans_bk=ci.trans_bk and si.trans_date= ci.trans_date) as inv_amt
#                                                        from sales_invoices si 
#                                                        --inner join customer_invoices ci  on  (si.trans_bk=ci.trans_bk and si.trans_date= ci.trans_date)
#                                                        left outer join users on si.created_by = users.id  where si.ref_trans_no = '#{order_trans_no}'"]
#   end  
  
#   def self.fetch_customer_card_transactions(order_id,trans_no,trans_bk)
#     CustomerCardTransaction::CustomerCardTransaction.find_by_sql ["select customer_card_transactions.trans_flag,customer_card_transactions.created_at,transaction_code,customer_profile_code,customer_payment_profile_code,
#                                                                    payment_capture_flag,payment_release_flag,authorization_code,account_number,authorized_amt,captured_amt,message_text,'CC' as type,
#                                                                    (select users.first_name+' '+users.last_name  from users where users.id = customer_card_transactions.created_by ) as authorized_by,
#                                                                    (select users.first_name+' '+users.last_name   from users where users.id = customer_card_transactions.updated_by ) as  modified_by,
#                                                                    convert(date,dateadd(day,30,customer_card_transactions.trans_date)) as expiration_date
#                                                                    from customer_card_transactions
#                                                                    where ref_trans_id = '#{order_id}'
#                                                                    and isnull(payment_release_flag,'N') = 'N'
#                                                                    union
#                                                                    select customer_card_transactions.trans_flag,customer_card_transactions.created_at,customer_receipts.trans_bk + '-' + customer_receipts.trans_no as transaction_code,'' as customer_profile_code,'' as customer_payment_profile_code,
#                                                                    payment_capture_flag,payment_release_flag,authorization_code,check_no as account_no,received_amt as authorized_amt,received_amt as captured_amt,'' as message_text,customer_receipts.receipt_type as type,
#                                                                    (select users.first_name+' '+users.last_name  from users where users.id = customer_card_transactions.created_by ) as authorized_by,
#                                                                    (select users.first_name+' '+users.last_name  from users where users.id = customer_card_transactions.updated_by )  as  modified_by,
#                                                                    convert(date,dateadd(day,30,customer_card_transactions.trans_date)) as expiration_date
#                                                                    from customer_receipts left outer join customer_card_transactions on (customer_receipts.check_no = customer_card_transactions.transaction_code and customer_receipts.ref_trans_bk = customer_card_transactions.ref_trans_bk )
#                                                                    where customer_receipts.ref_trans_no = '#{trans_no}' and customer_receipts.ref_trans_bk = '#{trans_bk}' and customer_receipts.trans_flag = 'A' and customer_card_transactions.id is null"]
#   end

#   def self.fetch_order_queries(order_id)  
#     Sales::Query.find_by_sql("SELECT queries.*,(users.first_name + ' ' + users.last_name)AS user_name
#                               FROM queries
#                               INNER JOIN users on users.id = queries.created_by
#                               WHERE queries.trans_flag = 'A' and queries.sales_order_id = #{order_id}")
#   end

#   def self.release_backorder(doc,schema_name)
#     id =  parse_xml(doc/:sales_order/'id') if (doc/:sales_order/'id').first
#     shipping_id =  parse_xml(doc/:sales_order/'shipping_id') if (doc/:sales_order/'shipping_id').first 
#     production_capacities = []
#     order = Sales::SalesOrder.find_by_id(id)  
#     #    order_lines = Sales::SalesOrderLine.where(:sales_order_id => id,:trans_flag => 'A',:item_type => CATALOG) 
#     #    order_line = order_lines.first if !order_lines.empty?
#     #    return if !order_line
#     shippings = Sales::SalesOrderShipping.where(:id => shipping_id, :trans_flag => 'A')
#     shipping = shippings.first if !shippings.empty?
#     return if !shipping
#     #    shipping.po_no = ''
#     #    shipping.po_arrival_date = nil
#     #    shipping.po_serial_no = nil
#     #    imprinttype = ''
#     #    order.sales_order_attributes_values.each{|soav|
#     #      if soav.catalog_attribute_code == 'IMPRINTTYPE' and soav.trans_flag == 'A'
#     #        imprinttype = soav.catalog_attribute_value_code
#     #        break
#     #      end
#     #    }
#     #    order_xml = "<sales_order>
#     #                    <catalog_item_id>#{order_line.catalog_item_id}</catalog_item_id>
#     #                    <ext_ref_date>#{order.ext_ref_date}</ext_ref_date>
#     #                    <customer_id>#{order.customer_id}</customer_id>
#     #                    <item_qty>#{shipping.ship_qty}</item_qty>
#     #                    <rushday>#{order.rush_order_type}</rushday>
#     #                    <imprinttype>#{imprinttype}</imprinttype>
#     #                    <next_day_flag>#{order.next_day_flag}</next_day_flag>
#     #                    <paper_proof_flag>#{order.paper_proof_flag}</paper_proof_flag>
#     #                    <blank_order_flag>#{order.blank_order_flag}</blank_order_flag>
#     #                    <is_calculation_on_po_arrival_date>false</is_calculation_on_po_arrival_date>
#     #                    <pre_prod_flag>#{shipping.pre_prod_flag}</pre_prod_flag>
#     #                    <trans_no>#{order.trans_no}</trans_no>
#     #                    <sales_order_shipping>
#     #                      <po_no>#{shipping.po_no}</po_no>
#     #                      <po_serial_no>#{shipping.po_serial_no}</po_serial_no>
#     #                      <po_arrival_date>#{shipping.po_arrival_date}</po_arrival_date>
#     #                      <pre_prod_flag>#{shipping.pre_prod_flag}</pre_prod_flag>
#     #                    </sales_order_shipping>
#     #               </sales_order>#"
#     #    doc = Hpricot::XML(order_xml)
#     #    estimated_ship_date = Sales::ShipDateUtility.get_estimated_ship_date_for_shipping(doc)
#     #    shipping.estimated_ship_date = estimated_ship_date
#     #    order_doc = Sales::ShipDateUtility.get_sales_order_xml(shipping)
#     #      order_tags = "<sales_order>
#     #                        <catalog_item_id>#{order_line.catalog_item_id}</catalog_item_id>
#     #                        <ext_ref_date>#{order.ext_ref_date}</ext_ref_date>
#     #                        <customer_id>#{order.customer_id}</customer_id>
#     #                        <item_qty>#{shipping.ship_qty}</item_qty>
#     #                        <rushday>#{order.rush_order_type}</rushday>
#     #                        <imprinttype>#{imprinttype}</imprinttype>
#     #                        <next_day_flag>#{order.next_day_flag}</next_day_flag>
#     #                        <paper_proof_flag>#{order.paper_proof_flag}</paper_proof_flag>
#     #                        <is_calculation_on_po_arrival_date>false</is_calculation_on_po_arrival_date>
#     #                        <blank_order_flag>#{order.blank_order_flag}</blank_order_flag
#     #                        <pre_prod_flag>#{shipping.pre_prod_flag}</pre_prod_flag>
#     #                        <trans_no>#{order.trans_no}</trans_no>
#     #" 
#     #      order_doc = order_tags + order_doc.split("<sales_order>").last
#     #      doc = Hpricot::XML(order_doc)
#     #    response = Sales::ShipDateUtility.calculate_inhand_dates(doc,shipping.estimated_ship_date,order_line.catalog_item_id,order.company_id,order.trans_no)
#     #    doc = Hpricot::XML(response)
#     #    error = parse_xml(doc/:errors/'error')
#     #    if !error.blank?
#     #      order.add_error("Release Backorder Error: #{error}")
#     #      return
#     #    else
#     #      shipping.estimated_ship_date = parse_xml(doc/:sales_order_shippings/:sales_order_shipping/'estimated_ship_date').to_s
#     #      shipping.estimated_arrival_date = parse_xml(doc/:sales_order_shippings/:sales_order_shipping/'estimated_arrival_date').to_s
#     #      if shipping.ship_date.blank?
#     #        shipping.internal_ship_date = shipping.estimated_ship_date
#     #        shipping.internal_inhand_date = shipping.estimated_arrival_date
#     #      end
#     #    end
#     #    min_ship_date ||= shipping.internal_ship_date
#     #    if min_ship_date
#     #      if shipping.internal_ship_date < min_ship_date
#     #        min_ship_date = shipping.internal_ship_date
#     #      end
#     #      order.ship_date = min_ship_date if min_ship_date
#     #    end
#     #    if(shipping.internal_ship_date_was and (shipping.internal_ship_date_was.to_date.strftime("%Y-%m-%d 00:00:00") != shipping.internal_ship_date.to_date.strftime("%Y-%m-%d 00:00:00")))
#     #      pdf_file_name_path = Shipping::PrawnFormats::ShipDateAlert.generate_ship_date_alert(order.id,shipping.id,schema_name,shipping.internal_ship_date,'RELEASE BACKORDER')
#     #      email = Email::Email.send_email('SHIPDATEALERT',order)
#     #      email.attachment_file = pdf_file_name_path
#     #      activity_message = "SHIP DATE CHANGED FROM #{shipping.internal_ship_date_was.to_date.strftime("%m/%d/%Y")} TO #{shipping.internal_ship_date.to_date.strftime("%m/%d/%Y")} : REASON - RELEASE BACKORDER"
#     #      order.create_sales_order_transaction_activity(activity_message)
#     #    end
#     #above code commented and defined in calling function for reusability
#     remove_po_from_shipping(order,shipping,production_capacities)
#     emails = Sales::ShipDateUtility.check_ship_date_change(order,schema_name,'RELEASE BACKORDER') if order.errors.blank?
#     save_proc = Proc.new{
#       #      shipping.save!
#       order.sales_order_shippings.each{|shipping| 
#         if shipping.id == shipping_id.to_i
#           shipping.save! 
#         end
#         break
#       }
#       order.save!
# #      production_capacities.each{|pc| pc.save!}
#       #      email.save! if !email.blank?
#       emails.each{|email| email.save!}
#     }
#     order.save_transaction(&save_proc)
#     return order
#   end 
  
#   def self.remove_po_from_shipping(sales_order,sales_order_shipping,production_capacities = [])
#     order_lines = Sales::SalesOrderLine.where(:sales_order_id => sales_order.id,:trans_flag => 'A',:item_type => CATALOG) 
#     order_line = order_lines.first if !order_lines.empty?
#     return if !order_line
#     imprinttype = ''
#     sales_order.sales_order_attributes_values.each{|soav|
#       if soav.catalog_attribute_code == 'IMPRINTTYPE' and soav.trans_flag == 'A'
#         imprinttype = soav.catalog_attribute_value_code
#         break
#       end
#     }
#     sales_order.sales_order_shippings.each{|shipping|
#       if shipping.id == sales_order_shipping.id
#         shipping.po_no = ''
#         shipping.po_arrival_date = nil
#         shipping.po_serial_no = nil
        
#         order_xml = "<sales_order>
#                     <catalog_item_id>#{order_line.catalog_item_id}</catalog_item_id>
#                     <ext_ref_date>#{sales_order.ext_ref_date}</ext_ref_date>
#                     <customer_id>#{sales_order.customer_id}</customer_id>
#                     <item_qty>#{shipping.ship_qty}</item_qty>
#                     <rushday>#{sales_order.rush_order_type}</rushday>
#                     <imprinttype>#{imprinttype}</imprinttype>
#                     <next_day_flag>#{sales_order.next_day_flag}</next_day_flag>
#                     <paper_proof_flag>#{sales_order.paper_proof_flag}</paper_proof_flag>
#                     <blank_order_flag>#{sales_order.blank_order_flag}</blank_order_flag>
#                     <is_calculation_on_po_arrival_date>false</is_calculation_on_po_arrival_date>
#                     <pre_prod_flag>#{shipping.pre_prod_flag}</pre_prod_flag>
#                     <trans_no>#{sales_order.trans_no}</trans_no>
#                     <sales_order_shipping>
#                       <po_no>#{shipping.po_no}</po_no>
#                       <po_serial_no>#{shipping.po_serial_no}</po_serial_no>
#                       <po_arrival_date>#{shipping.po_arrival_date}</po_arrival_date>
#                       <pre_prod_flag>#{shipping.pre_prod_flag}</pre_prod_flag>
#                     </sales_order_shipping>
#                </sales_order>"
#         doc = Hpricot::XML(order_xml)
#         estimated_ship_date = Sales::ShipDateUtility.get_estimated_ship_date_for_shipping(doc)
#         shipping.estimated_ship_date = estimated_ship_date
#         order_doc = Sales::ShipDateUtility.get_sales_order_xml(shipping)
#         order_tags = "<sales_order>
#                         <catalog_item_id>#{order_line.catalog_item_id}</catalog_item_id>
#                         <ext_ref_date>#{sales_order.ext_ref_date}</ext_ref_date>
#                         <order_ext_ref_date>#{sales_order.ext_ref_date}</order_ext_ref_date>
#                         <customer_id>#{sales_order.customer_id}</customer_id>
#                         <item_qty>#{shipping.ship_qty}</item_qty>
#                         <rushday>#{sales_order.rush_order_type}</rushday>
#                         <imprinttype>#{imprinttype}</imprinttype>
#                         <next_day_flag>#{sales_order.next_day_flag}</next_day_flag>
#                         <paper_proof_flag>#{sales_order.paper_proof_flag}</paper_proof_flag>
#                         <is_calculation_on_po_arrival_date>false</is_calculation_on_po_arrival_date>
#                         <blank_order_flag>#{sales_order.blank_order_flag}</blank_order_flag
#                         <pre_prod_flag>#{shipping.pre_prod_flag}</pre_prod_flag>
#                         <trans_no>#{sales_order.trans_no}</trans_no>
#                         <sales_order_po_no>#{sales_order.po_no}</sales_order_po_no>
#         " 
#         order_doc = order_tags + order_doc.split("<sales_order>").last
#         doc = Hpricot::XML(order_doc)
#         response = Sales::ShipDateUtility.calculate_inhand_dates(doc,shipping.estimated_ship_date,order_line.catalog_item_id,sales_order.company_id,sales_order.trans_no)
#         doc = Hpricot::XML(response)
#         error = parse_xml(doc/:errors/'error')
#         if !error.blank?
#           sales_order.add_error("Release Backorder Error: #{error}")
#           return
#         else
#           shipping.estimated_ship_date = parse_xml(doc/:sales_order_shippings/:sales_order_shipping/'estimated_ship_date').to_s
#           shipping.estimated_arrival_date = parse_xml(doc/:sales_order_shippings/:sales_order_shipping/'estimated_arrival_date').to_s
#           if shipping.ship_date.blank?
#             shipping.internal_ship_date = shipping.estimated_ship_date
#             shipping.internal_inhand_date = shipping.estimated_arrival_date
#           end
#         end
#         min_ship_date ||= shipping.internal_ship_date
#         if min_ship_date
#           if shipping.internal_ship_date < min_ship_date
#             min_ship_date = shipping.internal_ship_date
#           end
#           sales_order.ship_date = min_ship_date if min_ship_date
#         end
# #        if (nulltozero(shipping.ship_qty) > nulltozero(shipping.clear_qty))
# #          Sales::SalesOrderStatusUpdate.update_production_capacity(imprinttype,shipping,production_capacities)
# #        end
#         break
        
#       end
      
#     }
#   end

#   def self.search_sales_order_tekcard(doc)
#     company_id = doc["data"]["companyId"] ? doc["data"]["companyId"] : 1
#     trans_no_value = doc["data"]["transNo"] 
#     sub_order_flag = doc["data"]["subOrderFlag"] 
#     list = ActiveRecord::Base.connection.select_all("exec sp_promo_db_search_sales_order_tekcard
#                                                             '#{company_id}',
#                                                           '#{trans_no_value}','#{sub_order_flag}' ")
#     list
#   end

#   def self.get_order_details_tekcard(doc)
#     company_id = doc["data"]["companyId"] ? doc["data"]["companyId"] : 1
#     trans_no = doc["data"]["transNo"]
#     sales_order = Sales::SalesOrder.select(:id,:distributed_by_text).where(:trans_no => "#{trans_no}")
#     return '{"result":"errors","message":"Invalid Sales Order Trans No"}' if sales_order.blank?
#     if !sales_order.blank?
#       lines = Sales::SalesOrderLine.select(:catalog_item_code, :item_description,:item_qty,:indigo_code,:id).where(:sales_order_id => sales_order[0].id,:trans_flag => 'A',:item_type => INVENTORY,:company_id => 1) 
#       artwork = Sales::SalesOrderArtwork.select(:artwork_version,:artwork_file_path,:proof_file_name,:auto_proof_file_name,:id).where(:sales_order_id => sales_order[0].id ,:final_artwork_flag => 'Y' ,:trans_flag => 'A' ,:company_id=> 1).order(updated_at: :desc)
#       doc = {
#         order: sales_order,
#         lines: lines,
#         artwork: artwork
#       }
#       new_doc = {order_details:  doc}
#       return new_doc
#     end
#   end

#   def self.get_tekcard_orders(doc)
#    company_id = doc["data"]["companyId"] ? doc["data"]["companyId"] : 1
#    orders = Sales::SalesOrder.find_by_sql("SELECT [sales_order_lines].[item_description] AS [Description]
#                                   , [sales_orders].[ext_ref_no] AS [CustomerPONumber]
#                                   , [sales_orders].[customer_code] AS [CustomerNumber]
#                                   , [sales_order_lines].[trans_no] AS [TekweldSalesNumber]
#                                   , CAST([sales_order_lines].[item_qty] AS INT) AS [OrderCardsCount]
#                                   , [sales_orders].id as [id]
#                                    FROM [sales_order_lines]
#                                    LEFT JOIN [sales_orders] ON [sales_order_lines].[sales_order_id] = [sales_orders].[id]
#                                    WHERE [sales_order_lines].[catalog_item_code] = 'TCARD100'
#                                    AND [sales_order_lines].[workflow] = 'IN-HOUSE'
#                                    AND [sales_order_lines].[imprint_type] = 'DIGITEK'
#                                    AND [sales_order_lines].[item_qty] > [sales_order_lines].[clear_qty]
#                                    AND sales_orders.ordercancelstatus_flag <> 'Y'
#                                    and sales_orders.company_id = #{company_id}")
#    tekcard_orders = {orders: orders}
#    tekcard_orders
#   end

#   def self.fetch_sales_order_workflow_location(doc)
#     trans_nos = doc["data"]["transNo"] 
#     company_id = doc["data"]["companyId"] ? doc["data"]["companyId"] : 1
#     order_trans_no = []
#     trans_nos.each{|trans_no| order_trans_no << trans_no.to_s }
#     orders = Sales::SalesOrder.select(:id,:trans_no,:workflow_location).where(:trans_no => order_trans_no,:company_id => company_id)
#     sales_orders = {orders: orders}
#     sales_orders
#   end

#   def self.update_rip_flag_for_orders(doc)
#     begin
#       doc = JSON.parse(doc)
#       trans_nos = doc["data"]["transNo"]
#       trans_nos.each{|trans_no|
#       order = Sales::SalesOrder.where(:trans_no => trans_no)
#       line = Sales::SalesOrderLine.where(:sales_order_id => order.first.id,:item_type => 'I',:trans_flag => 'A')
#       activity_message = Sales::SalesOrderTransactionActivity.create_activity_message(order[0],"File Ripped from TekCard API")
#       order[0].create_sales_order_transaction_activity(activity_message)
#       save_proc = Proc.new{
#                   line[0].update_attributes(:rip_flag => 'Y')
#                   order[0].save!
#                 } 
#       line[0].save_transaction(&save_proc)
#       }
#       return true
#     rescue Exception => ex
#     return ex
#     end
#   end
  
#   def self.validate_print_inbox_json_data(doc)
#     begin
#       doc = JSON.parse(doc)
#       eventName =   doc["eventName"]
#       if eventName == 'IndigoPrintComplete'
#         trans_nos = doc["data"]["transNo"]   
#       else
#         trans_nos = doc["data"]   
#       end
#       trans_nos.each{|trans_no|
#         if eventName == 'IndigoPrintComplete'
#           order_no = trans_no
#         else
#           order_no = trans_no["trans_no"]
#         end
#         order = Sales::SalesOrder.where(:trans_no => order_no)
#         return "Invalid Sales Order #{order_no}",false if order.blank?
#         return "Order's #{order_no} Workflow Location should be INDIGO PRINT INBOX",false if order.first.workflow_location != 'INDIGO PRINT INBOX'
#         line = Sales::SalesOrderLine.where(:sales_order_id => order.first.id,:item_type => 'I',:trans_flag => 'A')
#         return "Order Line Does Not Exists for Order# #{order_no}",false if line.blank?
#         #return "Rip file activity not done for following Job# #{trans_no}.Please Rip these files first.",false if line.first.rip_flag != 'Y'
#       }
#       return "valid data",true    
#     rescue Exception => ex
#     return ex,false
#     end
#   end

#   def self.indigo_update_roll(doc)
#     begin
#     doc = JSON.parse(doc)
#     doc["data"].each{|trans_no|
#       roll_no = trans_no["rollNo"]
#       roll_lot_no = trans_no["rollLotNo"]
#       frames = trans_no["frames"] 
#       printed_qty = trans_no["actualPrintQuantity"]
#       roll_vendor = trans_no["rollVendor"][0..99] if trans_no["rollVendor"]
#       order = Sales::SalesOrder.where(:trans_no => trans_no["trans_no"])
#       line = Sales::SalesOrderLine.where(:sales_order_id => order.first.id,:item_type => 'I',:trans_flag => 'A')
#       activity_message = Sales::SalesOrderTransactionActivity.create_activity_message(order[0],"Roll#,Roll lot # and Frames,Printed Qty added from TekCard API")
#       order[0].create_sales_order_transaction_activity(activity_message)
#       save_proc = Proc.new{
#                   line[0].update_attributes(:roll_no => roll_no,:roll_lot_no => roll_lot_no,:no_of_frames => frames,:indigo_printed_qty => printed_qty,:roll_vendor => roll_vendor)
#                   order[0].save!
#                 } 
#       line[0].save_transaction(&save_proc)
#     }   
#     return true
#     rescue Exception => ex
#     return ex,false
#     end
#   end

#   def self.generate_xml_for_print_complete(doc)
#     begin
#       doc = JSON.parse(doc)
#       eventName =  doc["eventName"]
#       if eventName == 'IndigoPrintComplete'
#         trans_nos = doc["data"]["transNo"]
#         xml_doc = "<sales_orders>"
#         xml_body = ""
#         trans_nos.each{|trans_no|
#         line = Sales::SalesOrderLine.select(:roll_lot_no,:roll_no,:no_of_frames).where(:trans_flag => 'A',:item_type => 'I',:trans_no => trans_no).first
#         xml_body += "<sales_order>
#                     <trans_no>#{trans_no}</trans_no>
#                     <reject_yn>N</reject_yn>
#                     <reason></reason>
#                     <roll_no>#{line.roll_no}</roll_no>
#                     <roll_lot_no>#{line.roll_lot_no}</roll_lot_no>
#                     <no_of_frames>#{line.no_of_frames}</no_of_frames>
#                     <updated_by>46929</updated_by>
#                     <updated_by_code>TekCard</updated_by_code>
#                    </sales_order>"
#         }
#         xml_doc += xml_body
#         xml_doc += "</sales_orders>"
#       else
#         trans_nos = doc["data"]
#         xml_doc = "<sales_orders>"
#         xml_body = ""
#         trans_nos.each{|trans_no|
#           line = Sales::SalesOrderLine.select(:roll_lot_no,:roll_no,:no_of_frames).where(:trans_flag => 'A',:item_type => 'I',:trans_no => trans_no["trans_no"]).first
#           xml_body += "<sales_order>
#                     <trans_no>#{trans_no["trans_no"]}</trans_no>
#                     <reject_yn>Y</reject_yn>
#                     <reason>#{trans_no["reason"]}</reason>
#                     <roll_no>#{line.roll_no}</roll_no>
#                     <roll_lot_no>#{line.roll_lot_no}</roll_lot_no>
#                     <no_of_frames>#{line.no_of_frames}</no_of_frames>
#                     <updated_by>46929</updated_by>
#                     <updated_by_code>TekCard</updated_by_code>
#                    </sales_order>"
#         }
#         xml_doc += xml_body
#         xml_doc += "</sales_orders>"
#       end
#       return xml_doc
#     rescue Exception => ex
#     return ex  
#     end
#   end

#   def self.update_job_progress_and_print_status_in_order(log_filename,lines)
#     begin
#       log_file = File.open(log_filename, "w")
#       start_time= Time.now.strftime('%m-%d-%Y %H:%M:%S')
#       error = false
#       total_orders = 0
#       successfully_updated_orders = 0
#       lines.each{|record|
#         begin
#           total_orders += 1
#           data=record.split("\t")
#           trans_no=data[0]
#           print_status=data[1]
#           job_progress=data[2]
#           sales_order= Sales::SalesOrder.where("trans_no='#{trans_no}' and trans_flag='A'").first
#           if sales_order
#             sales_order.print_status=print_status
#             sales_order.job_progress=job_progress
#             save_proc = Proc.new{
#                 sales_order.save! if sales_order
#               }
#             sales_order.save_transaction(&save_proc)
#             if sales_order.errors.empty?
#               log_file.puts("Sales Order with order no #{trans_no} Updated successfully\n")
#               successfully_updated_orders+=1
#             else
#               log_file.puts("Sales Order with order no #{trans_no} not updated due to: #{sales_order.errors.messages.first}\n")
#             end
#           else
#             log_file.puts("Sales Order with order no #{trans_no} not found\n")
#           end 
#         rescue Exception => ex
#           error = true
#           log_file.puts("Sales Order with order no #{trans_no} not updated due to: #{ex.to_s}\n")
#         end
#         }
#     rescue Exception => ex
#       log_file.puts ex.to_s
#     ensure
#       log_file.puts("Start time : #{start_time}")
#       log_file.puts("End time : #{Time.now.strftime('%m-%d-%Y %H:%M:%S')}")
#       log_file.puts("Total Orders to be updated: #{total_orders}")
#       log_file.puts("Number of Successfully updated records: #{successfully_updated_orders}")
#       log_file.close
#       if (total_orders - successfully_updated_orders) == 0
#          result = 'success'
#       else
#          result = 'rejected'
#       end
#       return  result  
#     end
#   end

end  


