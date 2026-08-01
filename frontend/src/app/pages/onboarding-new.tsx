import { useState, useEffect } from "react";
import { useNavigate } from "react-router";
import { motion, AnimatePresence } from "motion/react";
import { Button } from "../components/ui/button";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";
import { Textarea } from "../components/ui/textarea";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "../components/ui/select";
import {
  Brain, User, School, MapPin, Phone, Shield, HelpCircle, CheckCircle2, Target, Briefcase, Palette, Rocket, ArrowRight, Sparkles, X, Gamepad2, Users, Wrench, FolderKanban, BookOpen, Lightbulb, Presentation, Heart, Hammer, RotateCcw, Scale, UserX, Eye, Repeat, GraduationCap, TrendingUp, Award, Clock, Video, Dumbbell, Music, MessageCircle, Home, Code,
  Coffee, ThumbsUp, ThumbsDown, Meh, Pencil, Map, Globe, DollarSign, TrendingDown,
  Smile, Zap, FileText, Navigation, Pause, AlertCircle, MessageSquare, Play, SkipForward,
} from "lucide-react";
import { Navbar } from "../components/navbar";
import { TranslatedText } from "../components/TranslatedText";
import { AptitudeGames } from "../components/aptitude-games";
import { SlidingTile } from "../components/aptitude-games";
import { ConstraintGrid } from "../components/aptitude-games";
import { SecretAgentCipher } from "../components/aptitude-games";
import type { PersistenceResult } from "../components/aptitude-games";
import type { ConstraintGridResult } from "../components/aptitude-games";
import type { SecretAgentResult, CipherQuestion } from "../components/aptitude-games";
import { useAuth } from "../contexts/AuthContext";

export function OnboardingNew() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const [currentStage, setCurrentStage] = useState(0); // 0 = Stage 0, 1 = Module 1, 2 = Module 2, 3 = Module 3, 4 = Module 4, 5 = Module 5, 6 = Module 6, 7 = Aptitude Games
  const [currentQuestion, setCurrentQuestion] = useState(1);
  const [dataLoaded, setDataLoaded] = useState(false);

  // Stage 0 - Onboarding Data
  const [name, setName] = useState("");
  const [classLevel, setClassLevel] = useState("");
  const [board, setBoard] = useState("");
  const [district, setDistrict] = useState("");
  const [parentMobile, setParentMobile] = useState("");
  const [consentChecked, setConsentChecked] = useState(false);

  // Module 1 - Opening Questions
  const [whyHere, setWhyHere] = useState("");
  const [fiveYearVision, setFiveYearVision] = useState("");
  const [careerThinking, setCareerThinking] = useState("");
  const [careerRuledOut, setCareerRuledOut] = useState("");

  // Module 2 - How Your Mind Works
  const [freeSunday, setFreeSunday] = useState("");
  const [groupRole, setGroupRole] = useState("");
  const [jobBothers, setJobBothers] = useState("");

  // Module 3 - What You're Actually Good At
  const [favoriteSubjects, setFavoriteSubjects] = useState<string[]>([]);
  const [difficultSubject, setDifficultSubject] = useState("");
  const [subjectMarks, setSubjectMarks] = useState<Record<string, string>>({});
  const [studyExperience, setStudyExperience] = useState("");

  // Module 4 - Life Outside Marks
  const [outsideActivities, setOutsideActivities] = useState<string[]>([]);
  const [externalValidation, setExternalValidation] = useState("");
  const [selfInitiated, setSelfInitiated] = useState("");

  // Module 5 - The Constraints
  const [studyLocation, setStudyLocation] = useState<string[]>([]);
  const [familyBudget, setFamilyBudget] = useState("");
  const [careerValues, setCareerValues] = useState<string[]>([]);

  // Module 6 - The Final Calibration
  const [planningStyle, setPlanningStyle] = useState("");
  const [stressResponse, setStressResponse] = useState("");
  const [surpriseReaction, setSurpriseReaction] = useState("");

  // Aptitude Games State
  const [currentGame, setCurrentGame] = useState(0); // 0 = intro, 1 = Number Sense, 2 = Word Sense, 3 = Shape Sense, 4 = Logic Sense
  const [gameRound, setGameRound] = useState(0); // Current round within game (0-3, 4 questions per game)
  const [gameDifficulty, setGameDifficulty] = useState(2); // 1=easy, 2=medium, 3=hard
  const [gameAnswers, setGameAnswers] = useState<Array<{correct: boolean, time: number}>>([]);
  const [allGameScores, setAllGameScores] = useState<{numberSense: number, wordSense: number, shapeSense: number, logicSense: number}>({numberSense: 0, wordSense: 0, shapeSense: 0, logicSense: 0});
  const [gameStartTime, setGameStartTime] = useState(0);
  const [showGameFeedback, setShowGameFeedback] = useState(false);
  const [gameFeedbackMessage, setGameFeedbackMessage] = useState("");

  // Game 5 â€” Persistence (Sliding Tile)
  const [persistenceResult, setPersistenceResult] = useState<PersistenceResult | null>(null);
  const [showPersistenceFeedback, setShowPersistenceFeedback] = useState(false);

  // Game 5 Task 2 â€” Constraint Grid
  const [constraintGridResult, setConstraintGridResult] = useState<ConstraintGridResult | null>(null);
  const [showConstraintFeedback, setShowConstraintFeedback] = useState(false);

  // Game 5 Task 3 â€” Secret Agent Cipher
  const [cipherQuestions, setCipherQuestions] = useState<{ tier1: CipherQuestion; tier2: CipherQuestion; tier3: CipherQuestion } | null>(null);
  const [cipherLoading, setCipherLoading] = useState(false);

  // Game 5 sub-task phase: 'tile' | 'grid' | 'story'
  const [game5Phase, setGame5Phase] = useState<'tile' | 'grid' | 'story'>('tile');

  // Personalized feedback state
  const [showFeedback, setShowFeedback] = useState(false);
  const [feedbackMessage, setFeedbackMessage] = useState("");
  const [feedbackLoading, setFeedbackLoading] = useState(false);
  const [feedbackLoadingPct, setFeedbackLoadingPct] = useState(0);

  // Scroll to top on stage/question change
  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: "smooth" });
  }, [currentStage, currentQuestion]);

  // Fetch saved onboarding data on mount
  useEffect(() => {
    const fetchOnboardingData = async () => {
      if (!user?.email || dataLoaded) return;
      
      try {
        const response = await fetch(
          `${import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080'}/api/get-onboarding`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username: user.email }),
          }
        );
        
        const result = await response.json();
        if (result.success && result.data) {
          setName(result.data.name || "");
          setClassLevel(result.data.classLevel || "");
          setBoard(result.data.board || "");
          setDistrict(result.data.district || "");
          setParentMobile(result.data.parentMobile || "");
          // Always reset consent to unchecked - user must give consent each time
          setConsentChecked(false);
        }
      } catch (error) {
        console.error('Failed to fetch onboarding data:', error);
      } finally {
        setDataLoaded(true);
      }
    };

    fetchOnboardingData();
  }, [user, dataLoaded]);

  // Validation for Stage 0
  const isStage0Valid = () => {
    return (
      name.trim() !== "" &&
      classLevel !== "" &&
      board !== "" &&
      district.trim() !== "" &&
      parentMobile.length === 10 &&
      consentChecked
    );
  };

  // Handle Stage 0 completion
  const handleStage0Complete = async () => {
    if (!isStage0Valid()) {
      alert("Please fill all required fields and provide consent");
      return;
    }
    
    // Save onboarding data to database
    if (user?.email) {
      try {
        await fetch(
          `${import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080'}/api/save-onboarding`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              username: user.email,
              name,
              classLevel,
              board,
              district,
              parentMobile,
            }),
          }
        );
      } catch (error) {
        console.error('Failed to save onboarding data:', error);
      }
    }
    
    setCurrentStage(1);
    setCurrentQuestion(1);
  };

  // Handle Module 1 & 2 question progression
  const handleNextQuestion = async () => {
    // Module 1 validations
    if (currentQuestion === 1 && !whyHere) {
      alert("Please select an option");
      return;
    }
    if (currentQuestion === 2 && !fiveYearVision) {
      alert("Please select an option");
      return;
    }

    // Module 2 validations
    if (currentQuestion === 5 && !freeSunday) {
      alert("Please select an option");
      return;
    }
    if (currentQuestion === 6 && !groupRole) {
      alert("Please select an option");
      return;
    }
    if (currentQuestion === 7 && !jobBothers) {
      alert("Please select an option");
      return;
    }

    // Module 3 validations
    if (currentQuestion === 8 && favoriteSubjects.length === 0) {
      alert("Please select at least one subject");
      return;
    }
    if (currentQuestion === 9 && !difficultSubject) {
      alert("Please select a subject");
      return;
    }
    if (currentQuestion === 10) {
      const allMarked = favoriteSubjects.every(sub => subjectMarks[sub]);
      if (!allMarked) {
        alert("Please select marks for all favorite subjects");
        return;
      }
    }
    if (currentQuestion === 11 && !studyExperience) {
      alert("Please select an option");
      return;
    }

    // Module 4 validations
    if (currentQuestion === 12 && outsideActivities.length === 0) {
      alert("Please select at least one activity");
      return;
    }
    if (currentQuestion === 13 && !externalValidation) {
      alert("Please select an option");
      return;
    }

    // Module 5 validations
    if (currentQuestion === 15 && studyLocation.length === 0) {
      alert("Please select at least one location");
      return;
    }
    if (currentQuestion === 16 && !familyBudget) {
      alert("Please select an option");
      return;
    }
    if (currentQuestion === 17 && careerValues.length < 2) {
      alert("Please select your top 2 values");
      return;
    }

    // Module 6 validations
    if (currentQuestion === 18 && !planningStyle) {
      alert("Please select an option");
      return;
    }
    if (currentQuestion === 19 && !stressResponse) {
      alert("Please select an option");
      return;
    }
    if (currentQuestion === 20 && !surpriseReaction) {
      alert("Please select an option");
      return;
    }

    if (currentQuestion === 4 || currentQuestion === 7 || currentQuestion === 11 || currentQuestion === 14 || currentQuestion === 17 || currentQuestion === 20) {
      // Show personalized AI feedback after each module
      const moduleMap: Record<number, number> = { 4: 1, 7: 2, 11: 3, 14: 4, 17: 5, 20: 6 };
      await generateFeedback(moduleMap[currentQuestion]);
    } else {
      setCurrentQuestion(currentQuestion + 1);
    }
  };

  // Build answers-so-far object for AI context
  const buildAnswersSoFar = (upToModule: number) => {
    const answers: Record<string, any> = {};
    if (upToModule >= 1) {
      answers.module1 = {
        whyHere, fiveYearVision,
        careerThinking: careerThinking || 'Not specified',
        careerRuledOut: careerRuledOut || 'Not specified',
      };
    }
    if (upToModule >= 2) {
      answers.module2 = { freeSunday, groupRole, jobBothers };
    }
    if (upToModule >= 3) {
      answers.module3 = { favoriteSubjects, difficultSubject, subjectMarks, studyExperience };
    }
    if (upToModule >= 4) {
      answers.module4 = {
        outsideActivities,
        externalValidation,
        selfInitiated: selfInitiated || 'Not specified',
      };
    }
    if (upToModule >= 5) {
      answers.module5 = { studyLocation, familyBudget, careerValues };
    }
    if (upToModule >= 6) {
      answers.module6 = { planningStyle, stressResponse, surpriseReaction };
    }
    return JSON.stringify(answers, null, 2);
  };

  // Generate personalized AI feedback
  const generateFeedback = async (moduleNumber: number) => {
    setFeedbackLoading(true);
    setFeedbackLoadingPct(0);
    setFeedbackMessage("");
    setShowFeedback(true);

    const ticker = setInterval(() => {
      setFeedbackLoadingPct(prev => prev < 85 ? prev + 7 : prev);
    }, 300);

    try {
      const response = await fetch(
        `${import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080'}/api/generate-module-feedback`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            module_number: moduleNumber,
            answers_so_far: buildAnswersSoFar(moduleNumber),
          }),
        }
      );
      const result = await response.json();
      clearInterval(ticker);
      setFeedbackLoadingPct(100);
      setFeedbackMessage(result.success ? result.feedback : "Let's keep going â€” your profile is taking shape.");
    } catch {
      clearInterval(ticker);
      setFeedbackLoadingPct(100);
      setFeedbackMessage("Let's keep going â€” your profile is taking shape.");
    } finally {
      setFeedbackLoading(false);
    }
  };
  // Handle feedback acknowledgment
  const handleFeedbackContinue = () => {
    setShowFeedback(false);
    if (currentStage === 1) {
      setCurrentStage(2);
      setCurrentQuestion(5);
    } else if (currentStage === 2) {
      setCurrentStage(3);
      setCurrentQuestion(8);
    } else if (currentStage === 3) {
      setCurrentStage(4);
      setCurrentQuestion(12);
    } else if (currentStage === 4) {
      setCurrentStage(5);
      setCurrentQuestion(15);
    } else if (currentStage === 5) {
      setCurrentStage(6);
      setCurrentQuestion(18);
    } else if (currentStage === 6) {
      // Move to Aptitude Games
      setCurrentStage(7);
      setCurrentGame(0);
    }
  };

  // Aptitude Games: Start game
  const handleStartGames = () => {
    setCurrentGame(1);
    setGameRound(0);
    setGameDifficulty(2);
    setGameAnswers([]);
    setGameStartTime(Date.now());
  };

  // Aptitude Games: Skip games
  const handleSkipGames = () => {
    // Games are mandatory - this function is no longer used
    navigate("/recommendations");
  };

  // Aptitude Games: Handle answer
  const handleGameAnswer = (isCorrect: boolean) => {
    const timeTaken = Date.now() - gameStartTime;
    const newAnswers = [...gameAnswers, { correct: isCorrect, time: timeTaken }];
    setGameAnswers(newAnswers);

    // Adaptive difficulty â€” factors in both correctness and speed
    const fast = timeTaken < 5000;
    if (isCorrect && fast && gameDifficulty < 3) {
      setGameDifficulty(gameDifficulty + 1); // correct + fast â†’ increase difficulty
    } else if (!isCorrect && gameDifficulty > 1) {
      setGameDifficulty(gameDifficulty - 1); // wrong â†’ decrease difficulty
    }
    // correct + slow â†’ hold difficulty steady

    // Move to next round or finish game
    if (gameRound >= 3) {
      generateGameFeedback(newAnswers);
      setShowGameFeedback(true);
    } else {
      setGameRound(gameRound + 1);
      setGameStartTime(Date.now());
    }
  };

  // Generate game feedback
  const generateGameFeedback = (answers: Array<{correct: boolean, time: number}>) => {
    // Weighted score: correct + fast (<5s) = 2pts, correct + slow = 1pt, wrong = 0
    const FAST_THRESHOLD = 5000;
    const weightedScore = answers.reduce((sum, a) => {
      if (!a.correct) return sum;
      return sum + (a.time < FAST_THRESHOLD ? 2 : 1);
    }, 0);

    const correctCount = answers.filter(a => a.correct).length;
    const allCorrect = correctCount === 4;
    const avgTime = answers.reduce((sum, a) => sum + a.time, 0) / answers.length;
    const fast = avgTime < FAST_THRESHOLD;

    // Store weighted score (0-8) for current game
    if (currentGame === 1) {
      setAllGameScores(prev => ({ ...prev, numberSense: weightedScore }));
    } else if (currentGame === 2) {
      setAllGameScores(prev => ({ ...prev, wordSense: weightedScore }));
    } else if (currentGame === 3) {
      setAllGameScores(prev => ({ ...prev, shapeSense: weightedScore }));
    } else if (currentGame === 4) {
      setAllGameScores(prev => ({ ...prev, logicSense: weightedScore }));
    }

    const gameLabels = ['', 'quantitative reasoning', 'verbal reasoning', 'spatial reasoning', 'abstract reasoning'];
    const label = gameLabels[currentGame];

    if (weightedScore >= 7) {
      // Fast + accurate
      setGameFeedbackMessage(`Exceptional ${label} â€” you were both fast and accurate. This is natural fluency, not just learned skill. Careers that demand quick ${label} under pressure would suit you well.`);
    } else if (weightedScore >= 5) {
      // Accurate but slower, or mix of fast+correct and slow+correct
      if (allCorrect && !fast) {
        setGameFeedbackMessage(`Strong ${label} â€” you got everything right but took your time. Accuracy is there; fluency is still building. Youâ€™d do well in roles where precision matters more than speed.`);
      } else {
        setGameFeedbackMessage(`Good ${label} â€” solid accuracy with decent pace. You can handle careers that rely on this skill, though high-pressure, fast-turnaround roles may need more practice.`);
      }
    } else if (weightedScore >= 3) {
      if (correctCount >= 3 && !fast) {
        setGameFeedbackMessage(`Moderate ${label} â€” youâ€™re accurate but slow. That tells us this doesnâ€™t come naturally yet â€” youâ€™re working it out rather than seeing it instantly. Careers requiring this skill are still possible with deliberate practice.`);
      } else {
        setGameFeedbackMessage(`Developing ${label} â€” some correct answers but inconsistent. This isnâ€™t a natural strength right now. Weâ€™ll weight your other aptitude scores more heavily in recommendations.`);
      }
    } else {
      setGameFeedbackMessage(`${label.charAt(0).toUpperCase() + label.slice(1)} isnâ€™t your natural strength â€” thatâ€™s honest data. Many successful careers donâ€™t depend on this skill. Your other scores will carry more weight in your recommendations.`);
    }
  };

  // Handle game feedback continue
  const handleGameFeedbackContinue = async () => {
    setShowGameFeedback(false);
    if (currentGame === 1) {
      // Move to Game 2 (Word Sense)
      setCurrentGame(2);
      setGameRound(0);
      setGameDifficulty(2);
      setGameAnswers([]);
      setGameStartTime(Date.now());
    } else if (currentGame === 2) {
      // Move to Game 3 (Shape Sense)
      setCurrentGame(3);
      setGameRound(0);
      setGameDifficulty(2);
      setGameAnswers([]);
      setGameStartTime(Date.now());
    } else if (currentGame === 3) {
      // Move to Game 4 (Logic Sense)
      setCurrentGame(4);
      setGameRound(0);
      setGameDifficulty(2);
      setGameAnswers([]);
      setGameStartTime(Date.now());
    } else if (currentGame === 4) {
      // All aptitude games complete â€” move to Game 5 (Persistence)
      setCurrentGame(5);
    }
  };

  // Game 5 â€” Persistence complete
  const handlePersistenceComplete = async (result: PersistenceResult) => {
    setPersistenceResult(result);
    setShowPersistenceFeedback(true);
  };

  const handlePersistenceSkip = async () => {
    setGame5Phase('grid');
  };

  const handlePersistenceFeedbackContinue = async () => {
    setShowPersistenceFeedback(false);
    setGame5Phase('grid');
  };

  // Task 2 â€” Constraint Grid
  const handleConstraintComplete = (result: ConstraintGridResult) => {
    setConstraintGridResult(result);
    setShowConstraintFeedback(true);
  };

  const handleConstraintSkip = () => {
    prefetchCipherQuestions();
    setGame5Phase('story');
  };

  const handleConstraintFeedbackContinue = () => {
    setShowConstraintFeedback(false);
    prefetchCipherQuestions();
    setGame5Phase('story');
  };

  // Pre-fetch cipher questions in background
  const prefetchCipherQuestions = async () => {
    if (cipherQuestions || cipherLoading) return;
    setCipherLoading(true);
    try {
      const res = await fetch(
        `${import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080'}/api/generate-cipher-questions`,
        { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({}) }
      );
      const data = await res.json();
      if (data.success) setCipherQuestions(data.questions);
    } catch { /* fallback: SecretAgentCipher shows error state */ }
    finally { setCipherLoading(false); }
  };

  // Task 3 â€” Secret Agent Cipher
  const handleCipherComplete = async (result: SecretAgentResult) => {
    await saveAssessmentData(persistenceResult, constraintGridResult, result);
    navigate("/recommendations");
  };

  const handleCipherSkip = async () => {
    await saveAssessmentData(persistenceResult, constraintGridResult, null);
    navigate("/recommendations");
  };

  const validateWord = async (word: string): Promise<boolean> => {
    try {
      const res = await fetch(
        `${import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080'}/api/validate-word`,
        { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ word }) }
      );
      const data = await res.json();
      return data.valid === true;
    } catch { return false; }
  };

  // Synthesize unified effortRating + approachStyle across all three tasks
  const synthesizeProfile = (
    persistence: PersistenceResult | null,
    cgResult: ConstraintGridResult | null,
    cipherRes: SecretAgentResult | null
  ): { effortRating: string; approachStyle: string } => {
    const t1Effort = persistence?.effortRating ?? '';
    const t2Shutdown = cgResult?.shutdownWithoutAttempt ?? false;

    let effortRating = t1Effort || 'You engage with familiar problems confidently but step back from unfamiliar ones.';
    if (t2Shutdown && cipherRes?.persistence === 'low') {
      effortRating = 'You move on quickly when a problem feels unsolvable â€” which has both strengths and costs depending on the career.';
    }

    const signals: string[] = [];
    if (persistence?.approachStyle) signals.push(persistence.approachStyle);
    if (cgResult?.approachLabel === 'systematic-analytical') signals.push('Systematic â€” you gather information before acting.');
    if (cgResult?.approachLabel === 'cautious') signals.push('Cautious â€” you prefer to understand the full picture before committing to any move.');
    if (cgResult?.approachLabel === 'intuitive-adaptive') signals.push('Intuitive â€” you act first and adjust from feedback.');
    if (cipherRes?.informationGathering === 'patient') signals.push('Systematic â€” you gather information before acting.');
    if (cipherRes?.informationGathering === 'impulsive') signals.push('Intuitive â€” you act first and adjust from feedback.');

    const systematicCount = signals.filter(s => s.startsWith('Systematic')).length;
    const intuitiveCount = signals.filter(s => s.startsWith('Intuitive')).length;
    const cautiousCount = signals.filter(s => s.startsWith('Cautious')).length;

    let approachStyle = persistence?.approachStyle || 'Intuitive â€” you act first and adjust from feedback.';
    if (systematicCount >= 2) approachStyle = 'Systematic â€” you gather information before acting.';
    else if (cautiousCount >= 2) approachStyle = 'Cautious â€” you prefer to understand the full picture before committing to any move.';
    else if (intuitiveCount >= 2) approachStyle = 'Intuitive â€” you act first and adjust from feedback.';

    return { effortRating, approachStyle };
  };

  // Save assessment data to backend
  const saveAssessmentData = async (persistence: PersistenceResult | null, cgResult: ConstraintGridResult | null, cipherRes: SecretAgentResult | null) => {
    if (!user?.email) return;

    const { effortRating, approachStyle } = synthesizeProfile(persistence, cgResult, cipherRes);

    try {
      const questionnaireData = {
        userProfile: {
          careerInterest: careerThinking || 'Not specified',
          subjects: favoriteSubjects,
          strengths: [],
          interests: outsideActivities,
        },
        whyHere, fiveYearVision, careerThinking, careerRuledOut, freeSunday, groupRole, jobBothers, favoriteSubjects, difficultSubject, subjectMarks, studyExperience, outsideActivities, externalValidation, selfInitiated, studyLocation, familyBudget, careerValues, planningStyle, stressResponse, surpriseReaction,
        numberSenseScore: allGameScores.numberSense,
        wordSenseScore: allGameScores.wordSense,
        shapeSenseScore: allGameScores.shapeSense,
        logicSenseScore: allGameScores.logicSense,
        persistenceEffortRating: effortRating,
        persistenceApproachStyle: approachStyle,
        persistenceCounselorFlags: [
          ...(persistence?.counselorFlags ?? []),
          ...(cgResult?.counselorFlag ? [cgResult.counselorFlag] : []),
          ...(cipherRes?.counselorFlags ?? []),
        ],
        persistenceHighestTier: persistence?.highestTier ?? null,
        constraintGridApproach: cgResult?.approachLabel ?? null,
        constraintGridSolved: cgResult?.solved ?? null,
        constraintGridCounselorFlag: cgResult?.counselorFlag ?? null,
        cipherInformationGathering: cipherRes?.informationGathering ?? null,
        cipherPersistence: cipherRes?.persistence ?? null,
        cipherRuleAdaptability: cipherRes?.ruleAdaptability ?? null,
        cipherSolved: cipherRes ? cipherRes.tierResults.every(r => r.solved) : null,
        cipherCounselorFlags: cipherRes?.counselorFlags ?? [],
      };

      await fetch(
        `${import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080'}/api/save-questionnaire`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            username: user.email,
            questionnaireData,
          }),
        }
      );
    } catch (error) {
      console.error('Failed to save assessment data:', error);
    }
  };
  // Skip option for Q3, Q4, and Q14
  const handleSkipQuestion = async () => {
    if (currentQuestion === 3) {
      setCareerThinking("");
      setCurrentQuestion(4);
    } else if (currentQuestion === 4) {
      setCareerRuledOut("");
      await generateFeedback(1);
    } else if (currentQuestion === 14) {
      setSelfInitiated("");
      await generateFeedback(4);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-indigo-50/30">
      <Navbar showHomeButton />

      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8 sm:py-12">
        {/* Header */}
        <div className="text-center mb-8">
          <div className="flex items-center justify-center gap-2 mb-4">
            <div className="w-12 h-12 bg-gradient-to-br from-indigo-600 to-purple-600 rounded-xl flex items-center justify-center">
              <Brain className="w-7 h-7 text-white" />
            </div>
            <span className="text-2xl font-bold bg-gradient-to-r from-indigo-600 to-purple-600 bg-clip-text text-transparent">
              EduBot
            </span>
          </div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            {currentStage === 0 ? <TranslatedText>Welcome! Let's Get Started</TranslatedText> : <TranslatedText>Let's Understand You Better</TranslatedText>}
          </h1>
          <p className="text-gray-600">
            {currentStage === 0 ? <TranslatedText>Takes about 60 seconds</TranslatedText> : <TranslatedText>A few quick questions to personalize your experience</TranslatedText>}
          </p>
        </div>

        {/* Progress Indicator */}
        <div className="mb-8">
          <div className="flex items-center justify-center gap-2 mb-2">
            <div className={`w-3 h-3 rounded-full ${currentStage >= 0 ? "bg-indigo-600" : "bg-gray-300"}`} />
            <div className={`w-3 h-3 rounded-full ${currentStage >= 1 ? "bg-indigo-600" : "bg-gray-300"}`} />
            <div className={`w-3 h-3 rounded-full ${currentStage >= 2 ? "bg-indigo-600" : "bg-gray-300"}`} />
            <div className={`w-3 h-3 rounded-full ${currentStage >= 3 ? "bg-indigo-600" : "bg-gray-300"}`} />
            <div className={`w-3 h-3 rounded-full ${currentStage >= 4 ? "bg-indigo-600" : "bg-gray-300"}`} />
            <div className={`w-3 h-3 rounded-full ${currentStage >= 5 ? "bg-indigo-600" : "bg-gray-300"}`} />
            <div className={`w-3 h-3 rounded-full ${currentStage >= 6 ? "bg-indigo-600" : "bg-gray-300"}`} />
          </div>
          <p className="text-center text-sm text-gray-600">
            {currentStage === 0 ? <TranslatedText>Step 1 of 7</TranslatedText> : 
             currentStage === 1 ? <TranslatedText>Step 2 of 7</TranslatedText> : 
             currentStage === 2 ? <TranslatedText>Step 3 of 7</TranslatedText> : 
             currentStage === 3 ? <TranslatedText>Step 4 of 7</TranslatedText> : 
             currentStage === 4 ? <TranslatedText>Step 5 of 7</TranslatedText> :
             currentStage === 5 ? <TranslatedText>Step 6 of 7</TranslatedText> : 
             <TranslatedText>Step 7 of 7</TranslatedText>}
          </p>
        </div>

        {/* Stage 0 - Onboarding Form */}
        {currentStage === 0 && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="bg-white rounded-2xl border border-gray-200 shadow-lg p-6 sm:p-8"
          >
            <div className="space-y-6">
              {/* Name */}
              <div className="space-y-2">
                <Label htmlFor="name" className="flex items-center gap-2">
                  <User className="w-4 h-4 text-indigo-600" />
                  <TranslatedText>Full Name</TranslatedText> *
                </Label>
                <Input
                  id="name"
                  placeholder="Enter your full name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="h-12"
                />
              </div>

              {/* Class */}
              <div className="space-y-2">
                <Label htmlFor="class" className="flex items-center gap-2">
                  <School className="w-4 h-4 text-indigo-600" />
                  <TranslatedText>Class</TranslatedText> *
                </Label>
                <Select value={classLevel} onValueChange={setClassLevel}>
                  <SelectTrigger id="class" className="h-12">
                    <SelectValue placeholder="Select your class" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="9"><TranslatedText>Class 9</TranslatedText></SelectItem>
                    <SelectItem value="10"><TranslatedText>Class 10</TranslatedText></SelectItem>
                    <SelectItem value="11"><TranslatedText>Class 11</TranslatedText></SelectItem>
                    <SelectItem value="12"><TranslatedText>Class 12</TranslatedText></SelectItem>
                    <SelectItem value="graduated"><TranslatedText>Graduate</TranslatedText>
                    </SelectItem>
                  </SelectContent>
                </Select>
              </div>

              {/* Board */}
              <div className="space-y-2">
                <Label htmlFor="board" className="flex items-center gap-2">
                  <School className="w-4 h-4 text-indigo-600" />
                  <TranslatedText>Board</TranslatedText> *
                </Label>
                <Select value={board} onValueChange={setBoard}>
                  <SelectTrigger id="board" className="h-12">
                    <SelectValue placeholder="Select your board" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="cbse"><TranslatedText>CBSE</TranslatedText></SelectItem>
                    <SelectItem value="icse"><TranslatedText>ICSE</TranslatedText></SelectItem>
                    <SelectItem value="state"><TranslatedText>State Board</TranslatedText></SelectItem>
                    <SelectItem value="ib"><TranslatedText>IB</TranslatedText></SelectItem>
                    <SelectItem value="other"><TranslatedText>Other</TranslatedText></SelectItem>
                  </SelectContent>
                </Select>
              </div>

              {/* District */}
              <div className="space-y-2">
                <Label htmlFor="district" className="flex items-center gap-2">
                  <MapPin className="w-4 h-4 text-indigo-600" />
                  <TranslatedText>District</TranslatedText> *
                </Label>
                <Input
                  id="district"
                  placeholder="Enter your district"
                  value={district}
                  onChange={(e) => setDistrict(e.target.value)}
                  className="h-12"
                />
              </div>

              {/* Parent Mobile */}
              <div className="space-y-2">
                <Label htmlFor="mobile" className="flex items-center gap-2">
                  <Phone className="w-4 h-4 text-indigo-600" />
                  <TranslatedText>Parent's Mobile Number</TranslatedText> *
                </Label>
                <Input
                  id="mobile"
                  type="tel"
                  placeholder="10-digit mobile number"
                  value={parentMobile}
                  onChange={(e) => {
                    const value = e.target.value.replace(/\D/g, "").slice(0, 10);
                    setParentMobile(value);
                  }}
                  className="h-12"
                />
              </div>

              {/* Consent Checkbox */}
              <div className="bg-indigo-50 border border-indigo-200 rounded-xl p-4">
                <div className="flex items-start gap-3">
                  <input
                    type="checkbox"
                    id="consent"
                    checked={consentChecked}
                    onChange={(e) => setConsentChecked(e.target.checked)}
                    className="mt-1 w-5 h-5 text-indigo-600 rounded focus:ring-indigo-500"
                  />
                  <div className="flex-1">
                    <Label htmlFor="consent" className="cursor-pointer flex items-center gap-2 font-medium text-gray-900">
                      <Shield className="w-4 h-4 text-indigo-600" />
                      <TranslatedText>Data Consent (Required for minors)</TranslatedText>
                    </Label>
                    <p className="text-sm text-gray-600 mt-1">
                      <TranslatedText>I consent to share my data with my parent/guardian for career guidance purposes as per DPDP Act compliance.</TranslatedText>
                    </p>
                  </div>
                </div>
              </div>

              {/* Continue Button */}
              <Button
                onClick={handleStage0Complete}
                disabled={!isStage0Valid()}
                className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700 text-white font-semibold"
              >
                <TranslatedText>Continue to Questions</TranslatedText>
                <ArrowRight className="w-5 h-5 ml-2" />
              </Button>
            </div>
          </motion.div>
        )}

        {/* Module 1 - Opening Questions */}
        {currentStage === 1 && !showFeedback && (
          <AnimatePresence mode="wait">
            <motion.div
              key={currentQuestion}
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              className="bg-white rounded-2xl border border-gray-200 shadow-lg p-6 sm:p-8"
            >
              {/* Question 1: Why are you here? */}
              {currentQuestion === 1 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-indigo-100 rounded-xl flex items-center justify-center">
                      <HelpCircle className="w-6 h-6 text-indigo-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>Why are you here today?</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 1 of 4</TranslatedText></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-4">
                    {[
                      { value: "no-idea", icon: HelpCircle, label: "I have no idea what to do after class 12" },
                      { value: "validate", icon: CheckCircle2, label: "I have a plan but want to check if it's right" },
                      { value: "disagree", icon: User, label: "My parents and I disagree about my career" },
                      { value: "explore", icon: Target, label: "I want to explore options before deciding" },
                    ].map((option) => (
                      <button
                        key={option.value}
                        onClick={() => setWhyHere(option.value)}
                        className={`p-5 rounded-xl border-2 text-left transition-all hover:scale-[1.02] ${
                          whyHere === option.value
                            ? "border-indigo-600 bg-indigo-50 shadow-lg"
                            : "border-gray-200 hover:border-indigo-300"
                        }`}
                      >
                        <div className="flex items-center gap-4">
                          <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                            whyHere === option.value ? "bg-indigo-600" : "bg-gray-100"
                          }`}>
                            <option.icon className={`w-6 h-6 ${whyHere === option.value ? "text-white" : "text-gray-600"}`} />
                          </div>
                          <span className="font-medium text-gray-900"><TranslatedText>{option.label}</TranslatedText></span>
                        </div>
                      </button>
                    ))}
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={!whyHere}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Next Question</TranslatedText>
                    <ArrowRight className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}

              {/* Question 2: Five years vision */}
              {currentQuestion === 2 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center">
                      <Sparkles className="w-6 h-6 text-purple-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>When you imagine yourself five years from now, which feels closest?</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 2 of 4</TranslatedText></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    {[
                      { value: "conventional", icon: Briefcase, label: "Wearing a uniform or lab coat, doing focused expert work" },
                      { value: "enterprising", icon: Target, label: "Leading a team, presenting ideas, making decisions" },
                      { value: "artistic", icon: Palette, label: "Creating something â€” designing, writing, building, performing" },
                      { value: "entrepreneurial", icon: Rocket, label: "Running my own thing, even if it's small" },
                    ].map((option) => (
                      <button
                        key={option.value}
                        onClick={() => setFiveYearVision(option.value)}
                        className={`p-6 rounded-xl border-2 text-left transition-all hover:scale-[1.02] ${
                          fiveYearVision === option.value
                            ? "border-indigo-600 bg-indigo-50 shadow-lg"
                            : "border-gray-200 hover:border-gray-300"
                        }`}
                      >
                        <div className={`w-14 h-14 rounded-xl flex items-center justify-center mb-4 ${
                          fiveYearVision === option.value ? "bg-indigo-600" : "bg-gray-100"
                        }`}>
                          <option.icon className={`w-7 h-7 ${fiveYearVision === option.value ? "text-white" : "text-gray-600"}`} />
                        </div>
                        <p className="font-medium text-gray-900 text-sm leading-relaxed"><TranslatedText>{option.label}</TranslatedText></p>
                      </button>
                    ))}
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={!fiveYearVision}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Next Question</TranslatedText>
                    <ArrowRight className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}

              {/* Question 3: Career thinking about */}
              {currentQuestion === 3 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-indigo-100 rounded-xl flex items-center justify-center">
                      <Target className="w-6 h-6 text-indigo-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>What's the one career you've been thinking about most?</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 3 of 4 â€¢ Optional</TranslatedText></p>
                    </div>
                  </div>

                  <div className="space-y-4">
                    <Textarea
                      placeholder="e.g., Doctor, Software Engineer, Designer..."
                      value={careerThinking}
                      onChange={(e) => setCareerThinking(e.target.value.slice(0, 50))}
                      className="min-h-[100px] text-lg"
                      maxLength={50}
                    />
                    <p className="text-sm text-gray-500 text-right">{careerThinking.length}/50 characters</p>
                  </div>

                  <div className="flex gap-3">
                    <Button
                      onClick={handleSkipQuestion}
                      variant="outline"
                      className="flex-1 h-12"
                    >
                      <TranslatedText>Skip â€” I really don't know</TranslatedText>
                    </Button>
                    <Button
                      onClick={handleNextQuestion}
                      className="flex-1 h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                    >
                      <TranslatedText>Next Question</TranslatedText>
                      <ArrowRight className="w-5 h-5 ml-2" />
                    </Button>
                  </div>
                </div>
              )}

              {/* Question 4: Career ruled out */}
              {currentQuestion === 4 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-red-100 rounded-xl flex items-center justify-center">
                      <X className="w-6 h-6 text-red-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>And one career you've ruled out?</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 4 of 4 â€¢ Optional</TranslatedText></p>
                    </div>
                  </div>

                  <div className="space-y-4">
                    <Textarea
                      placeholder="e.g., Engineering, Medicine, Teaching..."
                      value={careerRuledOut}
                      onChange={(e) => setCareerRuledOut(e.target.value.slice(0, 50))}
                      className="min-h-[100px] text-lg"
                      maxLength={50}
                    />
                    <p className="text-sm text-gray-500 text-right">{careerRuledOut.length}/50 characters</p>
                  </div>

                  <div className="flex gap-3">
                    <Button
                      onClick={handleSkipQuestion}
                      variant="outline"
                      className="flex-1 h-12"
                    >
                      <TranslatedText>Skip this question</TranslatedText>
                    </Button>
                    <Button
                      onClick={handleNextQuestion}
                      className="flex-1 h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                    >
                      <TranslatedText>Complete</TranslatedText>
                      <CheckCircle2 className="w-5 h-5 ml-2" />
                    </Button>
                  </div>
                </div>
              )}
            </motion.div>
          </AnimatePresence>
        )}

        {/* Personalized Feedback */}
        {showFeedback && (
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="bg-gradient-to-br from-indigo-50 to-purple-50 rounded-2xl border-2 border-indigo-200 shadow-xl p-8"
          >
            <div className="text-center mb-6">
              <div className="w-16 h-16 bg-gradient-to-br from-indigo-600 to-purple-600 rounded-full flex items-center justify-center mx-auto mb-4">
                <Sparkles className="w-8 h-8 text-white" />
              </div>
              <h2 className="text-2xl font-bold text-gray-900 mb-3"><TranslatedText>Here's what we noticed</TranslatedText></h2>
            </div>

            {feedbackLoading ? (
              <div className="bg-white rounded-xl p-6 mb-6 flex flex-col items-center gap-4">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" />
                <div className="w-full">
                  <div className="w-full bg-gray-100 rounded-full h-2 overflow-hidden mb-2">
                    <div
                      className="h-full bg-gradient-to-r from-indigo-500 to-purple-500 rounded-full transition-all duration-300"
                      style={{ width: `${feedbackLoadingPct}%` }}
                    />
                  </div>
                  <p className="text-sm font-semibold text-indigo-600 text-center">{feedbackLoadingPct}% â€” Analysing your answers...</p>
                </div>
              </div>
            ) : (
              <div className="bg-white rounded-xl p-6 mb-6">
                <p className="text-lg text-gray-700 leading-relaxed"><TranslatedText>{feedbackMessage}</TranslatedText></p>
              </div>
            )}

            <Button
              onClick={handleFeedbackContinue}
              disabled={feedbackLoading}
              className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700 text-white font-semibold disabled:opacity-50"
            >
              <TranslatedText>{currentStage === 6 ? "View Your Career Profile" : "Continue to Next Module"}</TranslatedText>
              <ArrowRight className="w-5 h-5 ml-2" />
            </Button>
          </motion.div>
        )}

        {/* Module 2 - How Your Mind Works */}
        {currentStage === 2 && !showFeedback && (
          <AnimatePresence mode="wait">
            <motion.div
              key={currentQuestion}
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              className="bg-white rounded-2xl border border-gray-200 shadow-lg p-6 sm:p-8"
            >
              {/* Question 5: Free Sunday */}
              {currentQuestion === 5 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center">
                      <Gamepad2 className="w-6 h-6 text-green-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>You have a free Sunday. Which sounds most fun?</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 5 of 7</TranslatedText></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-4">
                    {[
                      { value: "puzzle", icon: Lightbulb, label: "Solving a tricky puzzle or strategy game" },
                      { value: "friends", icon: Users, label: "Hanging out with friends and meeting new people" },
                      { value: "create", icon: Palette, label: "Making something â€” drawing, music, video, writing" },
                      { value: "build", icon: Wrench, label: "Fixing or building something with your hands" },
                      { value: "organize", icon: FolderKanban, label: "Organizing my room, my notes, my life" },
                      { value: "read", icon: BookOpen, label: "Reading about how the world works" },
                    ].map((option) => (
                      <button
                        key={option.value}
                        onClick={() => setFreeSunday(option.value)}
                        className={`p-5 rounded-xl border-2 text-left transition-all hover:scale-[1.02] ${
                          freeSunday === option.value
                            ? "border-indigo-600 bg-indigo-50 shadow-lg"
                            : "border-gray-200 hover:border-indigo-300"
                        }`}
                      >
                        <div className="flex items-center gap-4">
                          <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                            freeSunday === option.value ? "bg-indigo-600" : "bg-gray-100"
                          }`}>
                            <option.icon className={`w-6 h-6 ${freeSunday === option.value ? "text-white" : "text-gray-600"}`} />
                          </div>
                          <span className="font-medium text-gray-900"><TranslatedText>{option.label}</TranslatedText></span>
                        </div>
                      </button>
                    ))}
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={!freeSunday}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Next Question</TranslatedText>
                    <ArrowRight className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}

              {/* Question 6: Group project role */}
              {currentQuestion === 6 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center">
                      <Users className="w-6 h-6 text-blue-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>A group project lands in your lap. Without thinking, which role do you grab?</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 6 of 7</TranslatedText></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-4">
                    {[
                      { value: "plan", icon: Target, label: "The one who plans and divides the work" },
                      { value: "research", icon: BookOpen, label: "The one who does the research and analysis" },
                      { value: "present", icon: Presentation, label: "The one who makes it look good in the final presentation" },
                      { value: "motivate", icon: Heart, label: "The one who keeps everyone motivated and unstuck" },
                      { value: "execute", icon: Hammer, label: "The one who actually builds or executes it" },
                    ].map((option) => (
                      <button
                        key={option.value}
                        onClick={() => setGroupRole(option.value)}
                        className={`p-5 rounded-xl border-2 text-left transition-all hover:scale-[1.02] ${
                          groupRole === option.value
                            ? "border-indigo-600 bg-indigo-50 shadow-lg"
                            : "border-gray-200 hover:border-indigo-300"
                        }`}
                      >
                        <div className="flex items-center gap-4">
                          <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                            groupRole === option.value ? "bg-indigo-600" : "bg-gray-100"
                          }
                          `}>
                            <option.icon className={`w-6 h-6 ${groupRole === option.value ? "text-white" : "text-gray-600"}`} />
                          </div>
                          <span className="font-medium text-gray-900"><TranslatedText>{option.label}</TranslatedText></span>
                        </div>
                      </button>
                    ))}
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={!groupRole}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Next Question</TranslatedText>
                    <ArrowRight className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}

              {/* Question 7: Job deal-breakers */}
              {currentQuestion === 7 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-red-100 rounded-xl flex items-center justify-center">
                      <UserX className="w-6 h-6 text-red-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>Which of these would bother you most in a future job?</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 7 of 7</TranslatedText></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-4">
                    {[
                      { value: "repetitive", icon: Repeat, label: "Repeating the same task every day" },
                      { value: "decisions", icon: Scale, label: "Being responsible for big decisions and the blame if they're wrong" },
                      { value: "alone", icon: UserX, label: "Working alone without much human contact" },
                      { value: "no-result", icon: Eye, label: "Not being able to see a clear result of my work" },
                      { value: "strict-rules", icon: Shield, label: "Having to follow strict rules and procedures" },
                    ].map((option) => (
                      <button
                        key={option.value}
                        onClick={() => setJobBothers(option.value)}
                        className={`p-5 rounded-xl border-2 text-left transition-all hover:scale-[1.02] ${
                          jobBothers === option.value
                            ? "border-indigo-600 bg-indigo-50 shadow-lg"
                            : "border-gray-200 hover:border-indigo-300"
                        }`}
                      >
                        <div className="flex items-center gap-4">
                          <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                            jobBothers === option.value ? "bg-indigo-600" : "bg-gray-100"
                          }`}>
                            <option.icon className={`w-6 h-6 ${jobBothers === option.value ? "text-white" : "text-gray-600"}`} />
                          </div>
                          <span className="font-medium text-gray-900"><TranslatedText>{option.label}</TranslatedText></span>
                        </div>
                      </button>
                    ))}
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={!jobBothers}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Complete Module</TranslatedText>
                    <CheckCircle2 className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}
            </motion.div>
          </AnimatePresence>
        )}

        {/* Module 3 - What You're Actually Good At */}
        {currentStage === 3 && !showFeedback && (
          <AnimatePresence mode="wait">
            <motion.div
              key={currentQuestion}
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              className="bg-white rounded-2xl border border-gray-200 shadow-lg p-6 sm:p-8"
            >
              {/* Question 8: Favorite subjects */}
              {currentQuestion === 8 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-indigo-100 rounded-xl flex items-center justify-center">
                      <GraduationCap className="w-6 h-6 text-indigo-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>Pick your three favorite subjects this year</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 8 of 11 â€¢ Select up to 3</TranslatedText></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                    {[
                      "Physics", "Chemistry", "Biology", "Mathematics", 
                      "English", "Bengali", "Computer Science", "Economics",
                      "Geography", "History", "Political Science", "Accountancy"
                    ].map((subject) => {
                      const isSelected = favoriteSubjects.includes(subject);
                      return (
                        <button
                          key={subject}
                          onClick={() => {
                            if (isSelected) {
                              setFavoriteSubjects(favoriteSubjects.filter(s => s !== subject));
                            } else if (favoriteSubjects.length < 3) {
                              setFavoriteSubjects([...favoriteSubjects, subject]);
                            }
                          }}
                          disabled={!isSelected && favoriteSubjects.length >= 3}
                          className={`p-4 rounded-xl border-2 text-center transition-all ${
                            isSelected
                              ? "border-indigo-600 bg-indigo-50 shadow-md"
                              : favoriteSubjects.length >= 3
                              ? "border-gray-200 bg-gray-50 opacity-50 cursor-not-allowed"
                              : "border-gray-200 hover:border-indigo-300 hover:scale-105"
                          }`}
                        >
                          <span className={`font-medium text-sm ${
                            isSelected ? "text-indigo-900" : "text-gray-700"
                          }`}>
                            <TranslatedText>{subject}</TranslatedText>
                          </span>
                          {isSelected && (
                            <CheckCircle2 className="w-4 h-4 text-indigo-600 mx-auto mt-2" />
                          )}
                        </button>
                      );
                    })}
                  </div>

                  <div className="text-center text-sm text-gray-600">
                    <TranslatedText>{`${favoriteSubjects.length}/3 selected`}</TranslatedText>
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={favoriteSubjects.length === 0}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Next Question</TranslatedText>
                    <ArrowRight className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}

              {/* Question 9: Most difficult subject */}
              {currentQuestion === 9 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-orange-100 rounded-xl flex items-center justify-center">
                      <TrendingUp className="w-6 h-6 text-orange-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>Now pick the subject you find most difficult</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 9 of 11</TranslatedText></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                    {[
                      "Physics", "Chemistry", "Biology", "Mathematics", 
                      "English", "Bengali", "Computer Science", "Economics",
                      "Geography", "History", "Political Science", "Accountancy"
                    ].map((subject) => (
                      <button
                        key={subject}
                        onClick={() => setDifficultSubject(subject)}
                        className={`p-4 rounded-xl border-2 text-center transition-all hover:scale-105 ${
                          difficultSubject === subject
                            ? "border-orange-600 bg-orange-50 shadow-md"
                            : "border-gray-200 hover:border-orange-300"
                        }`}
                      >
                        <span className={`font-medium text-sm ${
                          difficultSubject === subject ? "text-orange-900" : "text-gray-700"
                        }`}>
                          <TranslatedText>{subject}</TranslatedText>
                        </span>
                      </button>
                    ))}
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={!difficultSubject}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Next Question</TranslatedText>
                    <ArrowRight className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}

              {/* Question 10: Marks in favorite subjects */}
              {currentQuestion === 10 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center">
                      <Award className="w-6 h-6 text-green-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>Your marks in the subjects you picked as favorites</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 10 of 11 â€¢ Pick the closest band</TranslatedText></p>
                    </div>
                  </div>

                  <div className="space-y-6">
                    {favoriteSubjects.map((subject) => (
                      <div key={subject} className="space-y-3">
                        <Label className="text-base font-semibold text-gray-900">
                          <TranslatedText>{subject}</TranslatedText>
                        </Label>
                        <div className="grid grid-cols-2 sm:grid-cols-5 gap-2">
                          {[
                            { value: "90+", label: "Above 90" },
                            { value: "80-90", label: "80-90" },
                            { value: "70-80", label: "70-80" },
                            { value: "60-70", label: "60-70" },
                            { value: "below-60", label: "Below 60" },
                          ].map((band) => (
                            <button
                              key={band.value}
                              onClick={() => setSubjectMarks({ ...subjectMarks, [subject]: band.value })}
                              className={`p-3 rounded-lg border-2 text-center transition-all ${
                                subjectMarks[subject] === band.value
                                  ? "border-green-600 bg-green-50 shadow-md"
                                  : "border-gray-200 hover:border-green-300"
                              }`}
                            >
                              <span className={`font-medium text-sm ${
                                subjectMarks[subject] === band.value ? "text-green-900" : "text-gray-700"
                              }`}>
                                <TranslatedText>{band.label}</TranslatedText>
                              </span>
                            </button>
                          ))}
                        </div>
                      </div>
                    ))}
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={!favoriteSubjects.every(sub => subjectMarks[sub])}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Next Question</TranslatedText>
                    <ArrowRight className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}

              {/* Question 11: Study experience */}
              {currentQuestion === 11 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center">
                      <Clock className="w-6 h-6 text-purple-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>When you study a subject you genuinely enjoy, what happens?</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 11 of 11</TranslatedText></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-4">
                    {[
                      { value: "flow", icon: Clock, label: "I lose track of time and hours pass" },
                      { value: "work", icon: TrendingUp, label: "I do well but it still feels like work" },
                      { value: "class-only", icon: Users, label: "I enjoy the class but struggle to study alone" },
                      { value: "videos", icon: Video, label: "I prefer learning from videos and discussion over textbooks" },
                    ].map((option) => (
                      <button
                        key={option.value}
                        onClick={() => setStudyExperience(option.value)}
                        className={`p-5 rounded-xl border-2 text-left transition-all hover:scale-[1.02] ${
                          studyExperience === option.value
                            ? "border-indigo-600 bg-indigo-50 shadow-lg"
                            : "border-gray-200 hover:border-indigo-300"
                        }`}
                      >
                        <div className="flex items-center gap-4">
                          <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                            studyExperience === option.value ? "bg-indigo-600" : "bg-gray-100"
                          }`}>
                            <option.icon className={`w-6 h-6 ${studyExperience === option.value ? "text-white" : "text-gray-600"}`} />
                          </div>
                          <span className="font-medium text-gray-900"><TranslatedText>{option.label}</TranslatedText></span>
                        </div>
                      </button>
                    ))}
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={!studyExperience}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Complete Module</TranslatedText>
                    <CheckCircle2 className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}
            </motion.div>
          </AnimatePresence>
        )}

        {/* Module 4 - Life Outside Marks */}
        {currentStage === 4 && !showFeedback && (
          <AnimatePresence mode="wait">
            <motion.div
              key={currentQuestion}
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              className="bg-white rounded-2xl border border-gray-200 shadow-lg p-6 sm:p-8"
            >
              {/* Question 12: Outside activities */}
              {currentQuestion === 12 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-pink-100 rounded-xl flex items-center justify-center">
                      <Heart className="w-6 h-6 text-pink-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>Outside studies, what do you actually spend time on?</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 12 of 14 â€¢ Select up to 3</TranslatedText></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-3">
                    {[
                      { value: "sports", icon: Dumbbell, label: "Sports / physical activity" },
                      { value: "creative", icon: Music, label: "Music, art, or creative hobbies" },
                      { value: "gaming", icon: Gamepad2, label: "Gaming" },
                      { value: "reading", icon: BookOpen, label: "Reading (non-textbook)" },
                      { value: "social-media", icon: MessageCircle, label: "Social media and chatting with friends" },
                      { value: "helping", icon: Home, label: "Helping at home, family business, or in the community" },
                      { value: "tech", icon: Code, label: "Building / coding / experimenting with tech" },
                      { value: "none", icon: Coffee, label: "Honestly, just studies and rest â€” no time for hobbies" },
                    ].map((option) => {
                      const isSelected = outsideActivities.includes(option.value);
                      return (
                        <button
                          key={option.value}
                          onClick={() => {
                            if (isSelected) {
                              setOutsideActivities(outsideActivities.filter(a => a !== option.value));
                            } else if (outsideActivities.length < 3) {
                              setOutsideActivities([...outsideActivities, option.value]);
                            }
                          }}
                          disabled={!isSelected && outsideActivities.length >= 3}
                          className={`p-4 rounded-xl border-2 text-left transition-all ${
                            isSelected
                              ? "border-indigo-600 bg-indigo-50 shadow-md"
                              : outsideActivities.length >= 3
                              ? "border-gray-200 bg-gray-50 opacity-50 cursor-not-allowed"
                              : "border-gray-200 hover:border-indigo-300 hover:scale-[1.02]"
                          }`}
                        >
                          <div className="flex items-center gap-4">
                            <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                              isSelected ? "bg-indigo-600" : "bg-gray-100"
                            }`}>
                              <option.icon className={`w-6 h-6 ${isSelected ? "text-white" : "text-gray-600"}`} />
                            </div>
                            <span className="font-medium text-gray-900"><TranslatedText>{option.label}</TranslatedText></span>
                          </div>
                        </button>
                      );
                    })}
                  </div>

                  <div className="text-center text-sm text-gray-600">
                    <TranslatedText>{`${outsideActivities.length}/3 selected`}</TranslatedText>
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={outsideActivities.length === 0}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Next Question</TranslatedText>
                    <ArrowRight className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}

              {/* Question 13: External validation */}
              {currentQuestion === 13 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center">
                      <ThumbsUp className="w-6 h-6 text-blue-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>Has anyone ever told you "you'd be great at ___"?</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 13 of 14</TranslatedText></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-4">
                    {[
                      { value: "agree", icon: ThumbsUp, label: "Yes, and I agree" },
                      { value: "unsure", icon: Meh, label: "Yes, but I'm not sure" },
                      { value: "disagree", icon: ThumbsDown, label: "Yes, but I don't want to do that" },
                      { value: "no", icon: HelpCircle, label: "No, not really" },
                    ].map((option) => (
                      <button
                        key={option.value}
                        onClick={() => setExternalValidation(option.value)}
                        className={`p-5 rounded-xl border-2 text-left transition-all hover:scale-[1.02] ${
                          externalValidation === option.value
                            ? "border-indigo-600 bg-indigo-50 shadow-lg"
                            : "border-gray-200 hover:border-indigo-300"
                        }`}
                      >
                        <div className="flex items-center gap-4">
                          <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                            externalValidation === option.value ? "bg-indigo-600" : "bg-gray-100"
                          }`}>
                            <option.icon className={`w-6 h-6 ${externalValidation === option.value ? "text-white" : "text-gray-600"}`} />
                          </div>
                          <span className="font-medium text-gray-900"><TranslatedText>{option.label}</TranslatedText></span>
                        </div>
                      </button>
                    ))}
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={!externalValidation}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Next Question</TranslatedText>
                    <ArrowRight className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}

              {/* Question 14: Self-initiated activity */}
              {currentQuestion === 14 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center">
                      <Pencil className="w-6 h-6 text-purple-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>Tell me about something you did in the last year without anyone asking you to</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 14 of 14 â€¢ Optional</TranslatedText></p>
                    </div>
                  </div>

                  <div className="space-y-4">
                    <Textarea
                      placeholder="e.g., Started a YouTube channel, organized a school event, learned a new skill..."
                      value={selfInitiated}
                      onChange={(e) => setSelfInitiated(e.target.value.slice(0, 200))}
                      className="min-h-[120px] text-lg"
                      maxLength={200}
                    />
                    <p className="text-sm text-gray-500 text-right">{selfInitiated.length}/200 characters</p>
                  </div>

                  <div className="flex gap-3">
                    <Button
                      onClick={handleSkipQuestion}
                      variant="outline"
                      className="flex-1 h-12"
                    >
                      <TranslatedText>Skip this question</TranslatedText>
                    </Button>
                    <Button
                      onClick={handleNextQuestion}
                      className="flex-1 h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                    >
                      <TranslatedText>Complete Assessment</TranslatedText>
                      <CheckCircle2 className="w-5 h-5 ml-2" />
                    </Button>
                  </div>
                </div>
              )}
            </motion.div>
          </AnimatePresence>
        )}

        {/* Module 5 - The Constraints */}
        {currentStage === 5 && !showFeedback && (
          <AnimatePresence mode="wait">
            <motion.div
              key={currentQuestion}
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              className="bg-white rounded-2xl border border-gray-200 shadow-lg p-6 sm:p-8"
            >
              {/* Question 15: Study location */}
              {currentQuestion === 15 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center">
                      <Map className="w-6 h-6 text-blue-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>Where are you open to studying?</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 15 of 20 â€¢ Select one option</TranslatedText></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-4">
                    {[
                      { value: "kolkata", icon: MapPin, label: "Only Kolkata" },
                      { value: "west-bengal", icon: Map, label: "Anywhere in West Bengal" },
                      { value: "india", icon: MapPin, label: "Anywhere in India" },
                      { value: "abroad", icon: Globe, label: "Open to studying abroad if it works out" },
                    ].map((option) => {
                      const isSelected = studyLocation.includes(option.value);
                      return (
                        <button
                          key={option.value}
                          onClick={() => setStudyLocation([option.value])}
                          className={`p-5 rounded-xl border-2 text-left transition-all hover:scale-[1.02] ${
                            isSelected
                              ? "border-indigo-600 bg-indigo-50 shadow-lg"
                              : "border-gray-200 hover:border-indigo-300"
                          }`}
                        >
                          <div className="flex items-center gap-4">
                            <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                              isSelected ? "bg-indigo-600" : "bg-gray-100"
                            }`}>
                              <option.icon className={`w-6 h-6 ${isSelected ? "text-white" : "text-gray-600"}`} />
                            </div>
                            <span className="font-medium text-gray-900"><TranslatedText>{option.label}</TranslatedText></span>
                          </div>
                        </button>
                      );
                    })}
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={studyLocation.length === 0}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Next Question</TranslatedText>
                    <ArrowRight className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}

              {/* Question 16: Family budget discussion */}
              {currentQuestion === 16 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center">
                      <DollarSign className="w-6 h-6 text-green-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>Have you talked to your family about the cost of higher education?</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 16 of 20</TranslatedText></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-4">
                    {[
                      { value: "clear-budget", icon: CheckCircle2, label: "Yes, and we have a clear budget" },
                      { value: "depends", icon: HelpCircle, label: "Yes, but it depends on the course" },
                      { value: "not-really", icon: Meh, label: "Not really" },
                      { value: "no-money-factor", icon: Sparkles, label: "I'd rather not factor money into this right now" },
                    ].map((option) => (
                      <button
                        key={option.value}
                        onClick={() => setFamilyBudget(option.value)}
                        className={`p-5 rounded-xl border-2 text-left transition-all hover:scale-[1.02] ${
                          familyBudget === option.value
                            ? "border-indigo-600 bg-indigo-50 shadow-lg"
                            : "border-gray-200 hover:border-indigo-300"
                        }`}
                      >
                        <div className="flex items-center gap-4">
                          <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                            familyBudget === option.value ? "bg-indigo-600" : "bg-gray-100"
                          }`}>
                            <option.icon className={`w-6 h-6 ${familyBudget === option.value ? "text-white" : "text-gray-600"}`} />
                          </div>
                          <span className="font-medium text-gray-900"><TranslatedText>{option.label}</TranslatedText></span>
                        </div>
                      </button>
                    ))}
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={!familyBudget}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Next Question</TranslatedText>
                    <ArrowRight className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}

              {/* Question 17: Career values (rank top 2) */}
              {currentQuestion === 17 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center">
                      <Heart className="w-6 h-6 text-purple-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>When you think about your career, which feels most important?</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 17 of 20 â€¢ Select your top 2</TranslatedText></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-4">
                    {[
                      { value: "earning", icon: TrendingUp, label: "Earning well, sooner rather than later" },
                      { value: "interest", icon: Heart, label: "Doing work that genuinely interests me" },
                      { value: "family-pride", icon: Award, label: "A career my family will be proud of" },
                      { value: "stability", icon: Shield, label: "Stability and security" },
                      { value: "impact", icon: Users, label: "Making a real impact on people or society" },
                    ].map((option) => {
                      const isSelected = careerValues.includes(option.value);
                      const rank = careerValues.indexOf(option.value) + 1;
                      return (
                        <button
                          key={option.value}
                          onClick={() => {
                            if (isSelected) {
                              setCareerValues(careerValues.filter(v => v !== option.value));
                            } else if (careerValues.length < 2) {
                              setCareerValues([...careerValues, option.value]);
                            }
                          }}
                          disabled={!isSelected && careerValues.length >= 2}
                          className={`p-5 rounded-xl border-2 text-left transition-all ${
                            isSelected
                              ? "border-indigo-600 bg-indigo-50 shadow-lg"
                              : careerValues.length >= 2
                              ? "border-gray-200 bg-gray-50 opacity-50 cursor-not-allowed"
                              : "border-gray-200 hover:border-indigo-300 hover:scale-[1.02]"
                          }`}
                        >
                          <div className="flex items-center gap-4">
                            <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                              isSelected ? "bg-indigo-600" : "bg-gray-100"
                            }`}>
                              {isSelected ? (
                                <span className="text-white font-bold text-lg">{rank}</span>
                              ) : (
                                <option.icon className="w-6 h-6 text-gray-600" />
                              )}
                            </div>
                            <span className="font-medium text-gray-900"><TranslatedText>{option.label}</TranslatedText></span>
                          </div>
                        </button>
                      );
                    })}
                  </div>

                  <div className="text-center text-sm text-gray-600">
                    <TranslatedText>{`${careerValues.length}/2 selected`}</TranslatedText>
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={careerValues.length < 2}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Complete Module</TranslatedText>
                    <CheckCircle2 className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}
            </motion.div>
          </AnimatePresence>
        )}

        {/* Module 6 - The Final Calibration */}
        {currentStage === 6 && !showFeedback && (
          <AnimatePresence mode="wait">
            <motion.div
              key={currentQuestion}
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              className="bg-white rounded-2xl border border-gray-200 shadow-lg p-6 sm:p-8"
            >
              {/* Question 18: Planning style */}
              {currentQuestion === 18 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-indigo-100 rounded-xl flex items-center justify-center">
                      <Navigation className="w-6 h-6 text-indigo-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>Pick the statement that sounds most like you</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 18 of 20</TranslatedText></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-4">
                    {[
                      { value: "clear-plan", icon: FileText, label: "I'd rather have a clear plan and follow it" },
                      { value: "options", icon: Navigation, label: "I'd rather have options and figure it out as I go" },
                      { value: "others", icon: Users, label: "I'd rather have someone tell me what's worked for others" },
                      { value: "try-things", icon: Zap, label: "I'd rather try things and see what fits" },
                    ].map((option) => (
                      <button
                        key={option.value}
                        onClick={() => setPlanningStyle(option.value)}
                        className={`p-5 rounded-xl border-2 text-left transition-all hover:scale-[1.02] ${
                          planningStyle === option.value
                            ? "border-indigo-600 bg-indigo-50 shadow-lg"
                            : "border-gray-200 hover:border-indigo-300"
                        }`}
                      >
                        <div className="flex items-center gap-4">
                          <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                            planningStyle === option.value ? "bg-indigo-600" : "bg-gray-100"
                          }`}>
                            <option.icon className={`w-6 h-6 ${planningStyle === option.value ? "text-white" : "text-gray-600"}`} />
                          </div>
                          <span className="font-medium text-gray-900"><TranslatedText>{option.label}</TranslatedText></span>
                        </div>
                      </button>
                    ))}
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={!planningStyle}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Next Question</TranslatedText>
                    <ArrowRight className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}

              {/* Question 19: Stress response */}
              {currentQuestion === 19 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-orange-100 rounded-xl flex items-center justify-center">
                      <AlertCircle className="w-6 h-6 text-orange-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>When something is stressful, what do you usually do?</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 19 of 20</TranslatedText></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-4">
                    {[
                      { value: "power-through", icon: Zap, label: "Power through and finish it" },
                      { value: "take-break", icon: Pause, label: "Take a break and come back to it" },
                      { value: "talk", icon: MessageSquare, label: "Talk to someone about it" },
                      { value: "procrastinate", icon: TrendingDown, label: "Get overwhelmed and procrastinate, honestly" },
                    ].map((option) => (
                      <button
                        key={option.value}
                        onClick={() => setStressResponse(option.value)}
                        className={`p-5 rounded-xl border-2 text-left transition-all hover:scale-[1.02] ${
                          stressResponse === option.value
                            ? "border-indigo-600 bg-indigo-50 shadow-lg"
                            : "border-gray-200 hover:border-indigo-300"
                        }`}
                      >
                        <div className="flex items-center gap-4">
                          <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                            stressResponse === option.value ? "bg-indigo-600" : "bg-gray-100"
                          }`}>
                            <option.icon className={`w-6 h-6 ${stressResponse === option.value ? "text-white" : "text-gray-600"}`} />
                          </div>
                          <span className="font-medium text-gray-900"><TranslatedText>{option.label}</TranslatedText></span>
                        </div>
                      </button>
                    ))}
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={!stressResponse}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Next Question</TranslatedText>
                    <ArrowRight className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}

              {/* Question 20: Surprise reaction */}
              {currentQuestion === 20 && (
                <div className="space-y-6">
                  <div className="flex items-center gap-3 mb-6">
                    <div className="w-12 h-12 bg-pink-100 rounded-xl flex items-center justify-center">
                      <Sparkles className="w-6 h-6 text-pink-600" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900"><TranslatedText>Last one â€” if your career assessment told you something surprising, would you...?</TranslatedText></h2>
                      <p className="text-sm text-gray-600"><TranslatedText>Question 20 of 20</TranslatedText></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-4">
                    {[
                      { value: "excited", icon: Smile, label: "Be excited to explore it" },
                      { value: "skeptical", icon: HelpCircle, label: "Be skeptical but curious" },
                      { value: "wrong", icon: X, label: "Feel like the system got it wrong" },
                      { value: "counselor", icon: MessageSquare, label: "Want to talk to a counselor about it" },
                    ].map((option) => (
                      <button
                        key={option.value}
                        onClick={() => setSurpriseReaction(option.value)}
                        className={`p-5 rounded-xl border-2 text-left transition-all hover:scale-[1.02] ${
                          surpriseReaction === option.value
                            ? "border-indigo-600 bg-indigo-50 shadow-lg"
                            : "border-gray-200 hover:border-indigo-300"
                        }`}
                      >
                        <div className="flex items-center gap-4">
                          <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                            surpriseReaction === option.value ? "bg-indigo-600" : "bg-gray-100"
                          }`}>
                            <option.icon className={`w-6 h-6 ${surpriseReaction === option.value ? "text-white" : "text-gray-600"}`} />
                          </div>
                          <span className="font-medium text-gray-900"><TranslatedText>{option.label}</TranslatedText></span>
                        </div>
                      </button>
                    ))}
                  </div>

                  <Button
                    onClick={handleNextQuestion}
                    disabled={!surpriseReaction}
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  >
                    <TranslatedText>Complete Assessment</TranslatedText>
                    <CheckCircle2 className="w-5 h-5 ml-2" />
                  </Button>
                </div>
              )}
            </motion.div>
          </AnimatePresence>
        )}

        {/* Aptitude Games - Intro Screen */}
        {currentStage === 7 && currentGame === 0 && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="bg-white rounded-2xl border border-gray-200 shadow-lg p-6 sm:p-8"
          >
            <div className="text-center mb-8">
              <div className="w-20 h-20 bg-gradient-to-br from-green-500 to-emerald-600 rounded-2xl flex items-center justify-center mx-auto mb-6">
                <Gamepad2 className="w-10 h-10 text-white" />
              </div>
              <h2 className="text-3xl font-bold text-gray-900 mb-4">
                <TranslatedText>Four Quick Games</TranslatedText>
              </h2>
              <p className="text-lg text-gray-600 mb-6">
                <TranslatedText>These tell us how your mind actually works â€” your aptitude pattern is the single hardest thing to fake, and it sharpens our recommendations significantly.</TranslatedText>
              </p>
            </div>

            <div className="space-y-4 mb-8">
              <div className="flex items-start gap-4 p-4 bg-indigo-50 rounded-xl">
                <div className="w-10 h-10 bg-indigo-600 rounded-lg flex items-center justify-center flex-shrink-0">
                  <span className="text-white font-bold">1</span>
                </div>
                <div>
                  <h3 className="font-semibold text-gray-900 mb-1"><TranslatedText>Number Sense</TranslatedText></h3>
                  <p className="text-sm text-gray-600"><TranslatedText>Sequences and arithmetic â€” measures quantitative reasoning (4 questions)</TranslatedText></p>
                </div>
              </div>

              <div className="flex items-start gap-4 p-4 bg-purple-50 rounded-xl">
                <div className="w-10 h-10 bg-purple-600 rounded-lg flex items-center justify-center flex-shrink-0">
                  <span className="text-white font-bold">2</span>
                </div>
                <div>
                  <h3 className="font-semibold text-gray-900 mb-1"><TranslatedText>Word Sense</TranslatedText></h3>
                  <p className="text-sm text-gray-600"><TranslatedText>Analogies and meanings â€” measures verbal reasoning (4 questions)</TranslatedText></p>
                </div>
              </div>

              <div className="flex items-start gap-4 p-4 bg-green-50 rounded-xl">
                <div className="w-10 h-10 bg-green-600 rounded-lg flex items-center justify-center flex-shrink-0">
                  <span className="text-white font-bold">3</span>
                </div>
                <div>
                  <h3 className="font-semibold text-gray-900 mb-1"><TranslatedText>Shape Sense</TranslatedText></h3>
                  <p className="text-sm text-gray-600"><TranslatedText>Rotation and visualization â€” measures spatial reasoning (4 questions)</TranslatedText></p>
                </div>
              </div>

              <div className="flex items-start gap-4 p-4 bg-orange-50 rounded-xl">
                <div className="w-10 h-10 bg-orange-600 rounded-lg flex items-center justify-center flex-shrink-0">
                  <span className="text-white font-bold">4</span>
                </div>
                <div>
                  <h3 className="font-semibold text-gray-900 mb-1"><TranslatedText>Logic Sense</TranslatedText></h3>
                  <p className="text-sm text-gray-600"><TranslatedText>Patterns and deduction â€” measures abstract reasoning (4 questions)</TranslatedText></p>
                </div>
              </div>
            </div>

            <div className="flex gap-3">
              <Button
                onClick={handleStartGames}
                className="w-full h-12 bg-gradient-to-r from-green-600 to-emerald-600 hover:from-green-700 hover:to-emerald-700"
              >
                <TranslatedText>Start Games</TranslatedText>
                <Play className="w-5 h-5 ml-2" />
              </Button>
            </div>
          </motion.div>
        )}

        {/* Aptitude Games - Active Game */}
        {currentStage === 7 && currentGame > 0 && currentGame <= 4 && !showGameFeedback && (
          <AptitudeGames
            gameType={currentGame as 1 | 2 | 3 | 4}
            difficulty={gameDifficulty as 1 | 2 | 3}
            round={gameRound}
            onAnswer={(result) => handleGameAnswer(result.isCorrect)}
          />
        )}

        {/* Game Feedback */}
        {showGameFeedback && (
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="bg-gradient-to-br from-green-50 to-emerald-50 rounded-2xl border-2 border-green-200 shadow-xl p-8"
          >
            <div className="text-center mb-6">
              <div className="w-16 h-16 bg-gradient-to-br from-green-600 to-emerald-600 rounded-full flex items-center justify-center mx-auto mb-4">
                <CheckCircle2 className="w-8 h-8 text-white" />
              </div>
              <h2 className="text-2xl font-bold text-gray-900 mb-3">
                <TranslatedText>
                  {currentGame === 1 ? "Number Sense Complete" : 
                   currentGame === 2 ? "Word Sense Complete" : 
                   currentGame === 3 ? "Shape Sense Complete" : 
                   "Logic Sense Complete"}
                </TranslatedText>
              </h2>
            </div>

            <div className="bg-white rounded-xl p-6 mb-6">
              <p className="text-lg text-gray-700 leading-relaxed">{gameFeedbackMessage}</p>
            </div>

            <Button
              onClick={handleGameFeedbackContinue}
              className="w-full h-12 bg-gradient-to-r from-green-600 to-emerald-600 hover:from-green-700 hover:to-emerald-700 text-white font-semibold"
            >
              <TranslatedText>{currentGame === 4 ? "View Your Career Profile" : "Next Game"}</TranslatedText>
              <ArrowRight className="w-5 h-5 ml-2" />
            </Button>
          </motion.div>
        )}
        {/* Game 5 â€” Persistence (Sliding Tile) */}
        {currentStage === 7 && currentGame === 5 && game5Phase === 'tile' && !showPersistenceFeedback && (
          <SlidingTile
            onComplete={handlePersistenceComplete}
            onSkip={handlePersistenceSkip}
          />
        )}

        {/* Game 5 â€” Persistence Feedback */}
        {showPersistenceFeedback && persistenceResult && (
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="bg-gradient-to-br from-teal-50 to-cyan-50 rounded-2xl border-2 border-teal-200 shadow-xl p-8"
          >
            <div className="text-center mb-6">
              <div className="w-16 h-16 bg-gradient-to-br from-teal-600 to-cyan-600 rounded-full flex items-center justify-center mx-auto mb-4">
                <CheckCircle2 className="w-8 h-8 text-white" />
              </div>
              <h2 className="text-2xl font-bold text-gray-900 mb-1">Here's what we noticed</h2>
              <p className="text-sm text-gray-500">Based on how you approached the puzzle</p>
            </div>
            <div className="space-y-4 mb-6">
              <div className="bg-white rounded-xl p-4 border border-teal-200">
                <p className="text-xs font-semibold text-teal-600 uppercase tracking-wide mb-1">Effort</p>
                <p className="text-gray-800">{persistenceResult.effortRating}</p>
              </div>
              <div className="bg-white rounded-xl p-4 border border-teal-200">
                <p className="text-xs font-semibold text-teal-600 uppercase tracking-wide mb-1">Approach</p>
                <p className="text-gray-800">{persistenceResult.approachStyle}</p>
              </div>
            </div>
            <Button
              onClick={handlePersistenceFeedbackContinue}
              className="w-full h-12 bg-gradient-to-r from-teal-600 to-cyan-600 hover:from-teal-700 hover:to-cyan-700 text-white font-semibold"
            >
              Continue
              <ArrowRight className="w-5 h-5 ml-2" />
            </Button>
          </motion.div>
        )}

        {/* Task 2 â€” Constraint Grid */}
        {currentStage === 7 && currentGame === 5 && game5Phase === 'grid' && !showConstraintFeedback && (
          <ConstraintGrid
            onComplete={handleConstraintComplete}
            onSkip={handleConstraintSkip}
          />
        )}

        {/* Task 2 â€” Constraint Grid Feedback */}
        {showConstraintFeedback && constraintGridResult && (
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="bg-gradient-to-br from-violet-50 to-purple-50 rounded-2xl border-2 border-violet-200 shadow-xl p-8"
          >
            <div className="text-center mb-6">
              <div className="w-16 h-16 bg-gradient-to-br from-violet-600 to-purple-600 rounded-full flex items-center justify-center mx-auto mb-4">
                <CheckCircle2 className="w-8 h-8 text-white" />
              </div>
              <h2 className="text-2xl font-bold text-gray-900 mb-1">Interesting.</h2>
              <p className="text-sm text-gray-500">One more puzzle to go.</p>
            </div>
            <div className="bg-white rounded-xl p-4 border border-violet-200 mb-6">
              <p className="text-xs font-semibold text-violet-600 uppercase tracking-wide mb-1">How you approached it</p>
              <p className="text-gray-800 capitalize">{constraintGridResult.approachLabel}</p>
            </div>
            <Button
              onClick={handleConstraintFeedbackContinue}
              className="w-full h-12 bg-gradient-to-r from-violet-600 to-purple-600 hover:from-violet-700 hover:to-purple-700 text-white font-semibold"
            >
              Last puzzle
              <ArrowRight className="w-5 h-5 ml-2" />
            </Button>
          </motion.div>
        )}


        {/* Task 3 - Secret Agent Cipher */}
        {currentStage === 7 && currentGame === 5 && game5Phase === 'story' && (
          <SecretAgentCipher
            questions={cipherQuestions}
            loading={cipherLoading}
            onValidateWord={validateWord}
            onComplete={handleCipherComplete}
            onSkip={handleCipherSkip}
          />
        )}
      </div>
    </div>
  );
}
