class ChatbotOptionCrud 
  

  def self.get_chatbot_options(option_type)
    ChatbotOption::ChatbotOption.where(option_type: option_type)
  end



end

