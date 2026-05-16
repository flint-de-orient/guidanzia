export type Language = 'en' | 'hi' | 'bn';

export interface LanguageOption {
  code: Language;
  name: string;
  nativeName: string;
  flag: string;
}

export const SUPPORTED_LANGUAGES: LanguageOption[] = [
  { code: 'en', name: 'English', nativeName: 'English', flag: '🇬🇧' },
  { code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', flag: '🇮🇳' },
  { code: 'bn', name: 'Bengali', nativeName: 'বাংলা', flag: '🇧🇩' },
];

const TRANSLATION_CACHE_KEY = 'edubot_translations';
const LANGUAGE_PREFERENCE_KEY = 'edubot_language';
const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';

class TranslationService {
  private cache: Map<string, Map<Language, string>>;
  private currentLanguage: Language;
  private translationPromises: Map<string, Promise<string>>;

  constructor() {
    this.cache = new Map();
    this.currentLanguage = 'en';
    this.translationPromises = new Map();
    this.loadCache();
    this.loadLanguagePreference();
  }

  private loadCache(): void {
    try {
      const cached = localStorage.getItem(TRANSLATION_CACHE_KEY);
      if (cached) {
        const parsed = JSON.parse(cached);
        this.cache = new Map(Object.entries(parsed).map(([key, value]) => [
          key,
          new Map(Object.entries(value as Record<string, string>))
        ]));
      }
    } catch (error) {
      console.error('Failed to load translation cache:', error);
    }
  }

  private saveCache(): void {
    try {
      const cacheObj: Record<string, Record<string, string>> = {};
      this.cache.forEach((langMap, text) => {
        const langObj: Record<string, string> = {};
        langMap.forEach((translation, lang) => {
          langObj[lang] = translation;
        });
        cacheObj[text] = langObj;
      });
      localStorage.setItem(TRANSLATION_CACHE_KEY, JSON.stringify(cacheObj));
    } catch (error) {
      console.error('Failed to save translation cache:', error);
    }
  }

  private loadLanguagePreference(): void {
    try {
      const saved = localStorage.getItem(LANGUAGE_PREFERENCE_KEY);
      if (saved && this.isValidLanguage(saved)) {
        this.currentLanguage = saved as Language;
      }
    } catch (error) {
      console.error('Failed to load language preference:', error);
    }
  }

  private saveLanguagePreference(lang: Language): void {
    try {
      localStorage.setItem(LANGUAGE_PREFERENCE_KEY, lang);
    } catch (error) {
      console.error('Failed to save language preference:', error);
    }
  }

  private isValidLanguage(code: string): boolean {
    return SUPPORTED_LANGUAGES.some(lang => lang.code === code);
  }

  getCurrentLanguage(): Language {
    return this.currentLanguage;
  }

  setLanguage(lang: Language): void {
    if (this.isValidLanguage(lang)) {
      this.currentLanguage = lang;
      this.saveLanguagePreference(lang);
    }
  }

  getCachedTranslation(text: string, targetLang: Language): string | null {
    const langMap = this.cache.get(text);
    if (langMap) {
      return langMap.get(targetLang) || null;
    }
    return null;
  }

  private cacheTranslation(text: string, targetLang: Language, translation: string): void {
    if (!this.cache.has(text)) {
      this.cache.set(text, new Map());
    }
    this.cache.get(text)!.set(targetLang, translation);
    this.saveCache();
  }

  async translate(text: string, targetLang: Language = this.currentLanguage): Promise<string> {
    if (targetLang === 'en' || !text || text.trim() === '') {
      return text;
    }

    const cached = this.getCachedTranslation(text, targetLang);
    if (cached) {
      return cached;
    }

    const cacheKey = `${text}_${targetLang}`;
    if (this.translationPromises.has(cacheKey)) {
      return this.translationPromises.get(cacheKey)!;
    }

    const translationPromise = this.performTranslation(text, targetLang);
    this.translationPromises.set(cacheKey, translationPromise);

    try {
      const result = await translationPromise;
      return result;
    } finally {
      this.translationPromises.delete(cacheKey);
    }
  }

  private async performTranslation(text: string, targetLang: Language): Promise<string> {
    try {
      const response = await fetch(`${API_BASE}/api/translate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          text,
          target_language: targetLang,
          source_language: 'en'
        }),
      });

      if (!response.ok) {
        throw new Error(`Translation API error: ${response.status}`);
      }

      const data = await response.json();
      
      if (data.success && data.translated_text) {
        this.cacheTranslation(text, targetLang, data.translated_text);
        return data.translated_text;
      } else {
        throw new Error(data.error || 'Translation failed');
      }
    } catch (error) {
      console.error('[TranslationService] Translation error:', error);
      return text;
    }
  }

  async translateBatch(texts: string[], targetLang: Language = this.currentLanguage): Promise<string[]> {
    if (targetLang === 'en') {
      return texts;
    }

    const results: string[] = [];
    const textsToTranslate: { index: number; text: string }[] = [];

    texts.forEach((text, index) => {
      const cached = this.getCachedTranslation(text, targetLang);
      if (cached) {
        results[index] = cached;
      } else {
        textsToTranslate.push({ index, text });
      }
    });

    if (textsToTranslate.length > 0) {
      try {
        const response = await fetch(`${API_BASE}/api/translate-batch`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            texts: textsToTranslate.map(t => t.text),
            target_language: targetLang,
            source_language: 'en'
          }),
        });

        if (response.ok) {
          const data = await response.json();
          if (data.success && Array.isArray(data.translations)) {
            data.translations.forEach((translation: string, i: number) => {
              const { index, text } = textsToTranslate[i];
              results[index] = translation;
              this.cacheTranslation(text, targetLang, translation);
            });
          }
        }
      } catch (error) {
        console.error('Batch translation error:', error);
      }
    }

    texts.forEach((text, index) => {
      if (!results[index]) {
        results[index] = text;
      }
    });

    return results;
  }

  clearCache(): void {
    this.cache.clear();
    try {
      localStorage.removeItem(TRANSLATION_CACHE_KEY);
    } catch (error) {
      console.error('Failed to clear cache:', error);
    }
  }

  getCacheSize(): number {
    return this.cache.size;
  }
}

export const translationService = new TranslationService();
