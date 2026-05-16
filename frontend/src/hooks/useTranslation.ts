import { useState, useEffect, useCallback } from 'react';
import { translationService, Language } from '../services/translationService';

export function useTranslation() {
  const [currentLanguage, setCurrentLanguage] = useState<Language>(() => {
    return translationService.getCurrentLanguage();
  });
  const [translationCache, setTranslationCache] = useState<Map<string, string>>(new Map());

  useEffect(() => {
    const handleLanguageChange = (e: Event) => {
      const customEvent = e as CustomEvent<{ language: Language }>;
      setCurrentLanguage(customEvent.detail.language);
      setTranslationCache(new Map());
    };

    const handleStorageChange = (e: StorageEvent) => {
      if (e.key === 'edubot_language' && e.newValue) {
        setCurrentLanguage(e.newValue as Language);
        setTranslationCache(new Map());
      }
    };

    window.addEventListener('languageChange', handleLanguageChange);
    window.addEventListener('storage', handleStorageChange);
    
    return () => {
      window.removeEventListener('languageChange', handleLanguageChange);
      window.removeEventListener('storage', handleStorageChange);
    };
  }, []);

  const t = useCallback(
    async (text: string): Promise<string> => {
      if (currentLanguage === 'en') {
        return text;
      }

      const cacheKey = `${text}_${currentLanguage}`;
      if (translationCache.has(cacheKey)) {
        return translationCache.get(cacheKey)!;
      }

      const translated = await translationService.translate(text, currentLanguage);
      setTranslationCache(prev => new Map(prev).set(cacheKey, translated));
      return translated;
    },
    [currentLanguage, translationCache]
  );

  const tSync = useCallback(
    (text: string): string => {
      if (currentLanguage === 'en') {
        return text;
      }

      const cacheKey = `${text}_${currentLanguage}`;
      if (translationCache.has(cacheKey)) {
        return translationCache.get(cacheKey)!;
      }

      translationService.translate(text, currentLanguage).then(translated => {
        setTranslationCache(prev => new Map(prev).set(cacheKey, translated));
      });

      return text;
    },
    [currentLanguage, translationCache]
  );

  const changeLanguage = useCallback((lang: Language) => {
    translationService.setLanguage(lang);
    setCurrentLanguage(lang);
    setTranslationCache(new Map());
    window.dispatchEvent(new CustomEvent('languageChange', { detail: { language: lang } }));
  }, []);

  return {
    t,
    tSync,
    currentLanguage,
    changeLanguage,
  };
}
