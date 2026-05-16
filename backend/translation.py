from deep_translator import GoogleTranslator
import logging

logger = logging.getLogger(__name__)

LANGUAGE_MAP = {'en': 'en', 'hi': 'hi', 'bn': 'bn'}

def translate_text(text, target_language='en', source_language='en'):
    try:
        if not text or text.strip() == '' or target_language == source_language:
            return text
        
        target_lang = LANGUAGE_MAP.get(target_language, 'en')
        source_lang = LANGUAGE_MAP.get(source_language, 'en')
        
        translator = GoogleTranslator(source=source_lang, target=target_lang)
        result = translator.translate(text)
        
        if result:
            logger.info(f"Translated: '{text[:50]}...' -> '{result[:50]}...' ({source_lang} -> {target_lang})")
            return result
        else:
            logger.warning(f"Translation returned empty result for: {text[:50]}")
            return text
    except Exception as e:
        logger.error(f"Translation error: {str(e)}")
        return text

def translate_batch(texts, target_language='en', source_language='en'):
    try:
        if not texts or len(texts) == 0 or target_language == source_language:
            return texts
        
        target_lang = LANGUAGE_MAP.get(target_language, 'en')
        source_lang = LANGUAGE_MAP.get(source_language, 'en')
        
        translator = GoogleTranslator(source=source_lang, target=target_lang)
        results = []
        
        for text in texts:
            if not text or text.strip() == '':
                results.append(text)
                continue
            
            try:
                result = translator.translate(text)
                results.append(result if result else text)
            except Exception as e:
                logger.error(f"Batch translation error for text: {text[:50]}: {str(e)}")
                results.append(text)
        
        logger.info(f"Batch translated {len(results)} texts ({source_lang} -> {target_lang})")
        return results
    except Exception as e:
        logger.error(f"Batch translation error: {str(e)}")
        return texts
