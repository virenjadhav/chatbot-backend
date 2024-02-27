class ChatbotOption < ApplicationRecord



  # def self.transaction_counts(doc)
    
  # end
  def self.get_chatbot_options(option_type)
    ChatbotOption.where(option_type: option_type)
  end
end