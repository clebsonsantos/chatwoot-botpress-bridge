require 'faraday'

class Chatwoot::SendToBotpress < Micro::Case
  attributes :event
  attributes :botpress_endpoint
  attributes :botpress_bot_id

  def call!
    conversation_id = event['conversation']['id']
    message_content = event['content']
    url = "#{botpress_endpoint}/api/v1/bots/#{botpress_bot_id}/converse/#{conversation_id}"

    body = {
      'text': "#{message_content}",
      'type': 'text',
      'metadata': {
        'event': event
      }
    }

    body['text'] = process_message(body)

    response = Faraday.post(url, body.to_json, {'Content-Type': 'application/json'})

    Rails.logger.info("Botpress response")
    Rails.logger.info("Status code: #{response.status}")
    Rails.logger.info("Body: #{response.body}")

    if (response.status == 200)
      Success result: JSON.parse(response.body)
    elsif (response.status == 404 && response.body.include?('Invalid Bot ID'))
      Failure result: { message: 'Invalid Bot ID' }
    else
      Failure result: { message: 'Invalid botpress endpoint' }
    end
  end

  def process_message(message)
    attachments = message.dig("metadata", "event", "attachments")
    return message['text'].to_s unless attachments && !attachments.empty?
  
    media = attachments[0]
    audio_url = media["data_url"] if media["file_type"] == "audio"
    image_url = media["data_url"] if media["file_type"] == "image"
    video_url = media["data_url"] if media["file_type"] == "video"
    type = media["file_type"]
  
    enable_text_audio = get_app_setting_value(:botpress_enable_text_reference_for_media_audio)
    enable_text_video = get_app_setting_value(:botpress_enable_text_reference_for_media_video)
    enable_text_image = get_app_setting_value(:botpress_enable_text_reference_for_media_image)
    enable_text_document = get_app_setting_value(:botpress_enable_text_reference_for_media_document)
  
    audio = enable_text_audio ? "Enviando @media:audio" : message['text'].to_s
    video = enable_text_video ? "Enviando @media:video" : message['text'].to_s
    image = enable_text_image ? "Enviando @media:image" : message['text'].to_s
    document = enable_text_document ? "Enviando @media:document" : message['text'].to_s
  
    case type
    when "audio"
      audio
    when "video"
      video
    when "image"
      image
    when "file"
      if audio_url&.length.to_i > 0
        audio
      elsif video_url&.length.to_i > 0
        video
      elsif image_url&.length.to_i > 0
        image
      else
        document
      end
    else
      message['text'].to_s
    end
  end
  
  
  def get_app_setting_value(key)
    env_variable_mapping = {
      botpress_enable_text_reference_for_media_audio: 'BOTPRESS_ENABLE_TEXT_REFERENCE_FOR_MEDIA_AUDIO',
      botpress_enable_text_reference_for_media_video: 'BOTPRESS_ENABLE_TEXT_REFERENCE_FOR_MEDIA_VIDEO',
      botpress_enable_text_reference_for_media_image: 'BOTPRESS_ENABLE_TEXT_REFERENCE_FOR_MEDIA_IMAGE',
      botpress_enable_text_reference_for_media_document: 'BOTPRESS_ENABLE_TEXT_REFERENCE_FOR_MEDIA_DOCUMENT'
    }
  
    env_key = env_variable_mapping[key]
    ENV.fetch(env_key, nil) if env_key
  end
  
end