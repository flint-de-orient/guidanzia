import { useState, useEffect } from 'react';
import { useTranslation } from '../../hooks/useTranslation';
import { translationService } from '../../services/translationService';

interface TranslatedTextProps {
  children: string;
  className?: string;
  as?: keyof JSX.IntrinsicElements;
}

export function TranslatedText({ children, className, as: Component = 'span' }: TranslatedTextProps) {
  const { currentLanguage } = useTranslation();
  const [translatedText, setTranslatedText] = useState(children);

  useEffect(() => {
    if (currentLanguage === 'en') {
      setTranslatedText(children);
      return;
    }

    const cached = translationService.getCachedTranslation(children, currentLanguage);
    if (cached) {
      setTranslatedText(cached);
      return;
    }

    translationService.translate(children, currentLanguage)
      .then(translated => {
        setTranslatedText(translated);
      })
      .catch(() => {
        setTranslatedText(children);
      });
  }, [children, currentLanguage]);

  return <Component className={className}>{translatedText}</Component>;
}
