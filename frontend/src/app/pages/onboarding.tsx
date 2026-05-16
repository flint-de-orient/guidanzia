import { useState, useEffect, useCallback } from "react";
import { useNavigate, Link } from "react-router";
import { motion } from "motion/react";
import { Button } from "../components/ui/button";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";
import { Textarea } from "../components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "../components/ui/select";
import { Slider } from "../components/ui/slider";
import {
  RadioGroup,
  RadioGroupItem,
} from "../components/ui/radio-group";
import {
  Brain,
  GraduationCap,
  Target,
  CheckCircle2,
  ArrowRight,
  ArrowLeft,
  BookOpen,
  Zap,
  Rocket,
  Sparkles,
} from "lucide-react";
import { Navbar } from "../components/navbar";
import { TranslatedText } from "../components/TranslatedText";

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';

// Session management function
const saveSessionToServer = async (overrides: any = {}) => {
  try {
    const user = (() => {
      try { return JSON.parse(localStorage.getItem('edubot_user') || 'null'); } catch { return null; }
    })();
    if (!user?.email) return;

    const recommendations = (() => {
      try { return JSON.parse(sessionStorage.getItem('careerRecommendations') || 'null'); } catch { return null; }
    })();
    const userProfile = (() => {
      try { return JSON.parse(sessionStorage.getItem('userProfile') || 'null'); } catch { return null; }
    })();
    const lastRole = (() => {
      try {
        const raw = localStorage.getItem('edubot_last_role');
        return raw ? JSON.parse(raw) : null;
      } catch { return null; }
    })();

    await fetch(`${API_BASE}/api/save-session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: user.email,
        recommendations,
        userProfile,
        lastRoleId: lastRole?.roleId ?? null,
        lastRoleTitle: lastRole?.roleTitle ?? null,
        ...overrides,
      }),
    });
  } catch { /* non-critical */ }
};

// Transform profile for API
function transformProfile(formState: any) {
  const {
    educationLevel, subjects, interests, performance, experienceLevel, learningCommitment, careerPriority, workStyle, additionalNotes, stressHandling, motivationType, teamworkPreference, challengePreference, decisionMaking,
  } = formState;

  return {
    profile: {
      careerInterest: interests.length > 0 ? interests.join(', ') : 'General',
      education: educationLevel,
      subjects: subjects,
      performance: Array.isArray(performance) ? performance[0] : performance,
      testimony: additionalNotes || '',
      experienceLevel: experienceLevel || '',
      learningCommitment: learningCommitment || '',
      careerPriority: careerPriority || '',
      workStyle: workStyle || '',
      stressHandling: stressHandling || '',
      motivationType: motivationType || '',
      teamworkPreference: teamworkPreference || '',
      challengePreference: challengePreference || '',
      decisionMaking: decisionMaking || '',
    },
  };
}

// Fetch career recommendations from API
async function fetchCareerRecommendations(payload: any) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 60000);

  try {
    const response = await fetch(`${API_BASE}/api/career-recommendations`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    clearTimeout(timer);

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const data = await response.json();
    return data;
  } catch (err: any) {
    clearTimeout(timer);
    if (err.name === 'AbortError') {
      throw new Error('Request timed out. The AI is taking too long — please try again.');
    }
    throw err;
  }
}

export function Onboarding() {
  const navigate = useNavigate();
  const [currentStep, setCurrentStep] = useState(1);
  const totalSteps = 3;

  // Scroll to top whenever the step changes
  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: "smooth" });
  }, [currentStep]);

  // Step 1 - Student Profile
  const [educationLevel, setEducationLevel] = useState("");
  const [subjects, setSubjects] = useState<string[]>([]);
  const [interests, setInterests] = useState<string[]>([]);
  const [performance, setPerformance] = useState([0]);

  // Step 2 - Career Preferences
  const [experienceLevel, setExperienceLevel] = useState("");
  const [learningCommitment, setLearningCommitment] =
    useState("");
  const [careerPriority, setCareerPriority] = useState("");
  const [workStyle, setWorkStyle] = useState("");
  const [additionalNotes, setAdditionalNotes] = useState("");

  // Step 3 - Professional Assessment
  const [stressHandling, setStressHandling] = useState("");
  const [motivationType, setMotivationType] = useState("");
  const [teamworkPreference, setTeamworkPreference] =
    useState("");
  const [challengePreference, setChallengePreference] =
    useState("");
  const [decisionMaking, setDecisionMaking] = useState("");

  const subjectOptions = [
    "Mathematics", "Physics", "Chemistry", "Biology", "Computer Science", "Economics", "Business Studies", "Statistics", "English", "Arts & Design",
  ];

  const interestOptions = [
    "Data Science", "Software Development", "Business Analytics", "Healthcare", "Finance", "Marketing", "Design", "Research",
  ];

  const toggleSelection = (
    value: string,
    list: string[],
    setter: (val: string[]) => void,
  ) => {
    if (list.includes(value)) {
      setter(list.filter((item) => item !== value));
    } else {
      setter([...list, value]);
    }
  };

  const onSuccess = useCallback((data: unknown) => {
    setGenProgress(100);
    setTimeout(() => {
      // Clear any stale job detail caches from previous sessions
      const staleKeys: string[] = [];
      for (let i = 0; i < sessionStorage.length; i++) {
        const k = sessionStorage.key(i);
        if (k && k.startsWith('jobDetail_')) staleKeys.push(k);
      }
      staleKeys.forEach((k) => sessionStorage.removeItem(k));
      // Save API response and the user profile separately
      sessionStorage.setItem("careerRecommendations", JSON.stringify(data));
      // Also save to localStorage for persistence across sessions
      localStorage.setItem("careerRecommendations", JSON.stringify(data));
      const profile = {
        education: educationLevel,
        subjects, interests,
        performance: Array.isArray(performance) ? performance[0] : performance,
        testimony: additionalNotes,
        experienceLevel, learningCommitment, careerPriority, workStyle, stressHandling, motivationType, teamworkPreference, challengePreference, decisionMaking,
      };
      sessionStorage.setItem("userProfile", JSON.stringify(profile));
      localStorage.setItem("userProfile", JSON.stringify(profile));
      // Persist to server so it survives re-login
      saveSessionToServer({ recommendations: data, userProfile: profile });
      navigate("/recommendations");
    }, 400);
  }, [navigate, educationLevel, subjects, interests, performance, additionalNotes, experienceLevel, learningCommitment, careerPriority, workStyle, stressHandling, motivationType, teamworkPreference, challengePreference, decisionMaking]);

  // Inline API submission logic (replacing useFlowController)
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (formState: any) => {
    setLoading(true);
    setError(null);

    try {
      const payload = transformProfile(formState);
      const data = await fetchCareerRecommendations(payload);

      if (!data.success) {
        throw new Error(data.error || 'Career generation failed');
      }

      onSuccess(data);
    } catch (err: any) {
      setError(err.message || 'An unexpected error occurred');
    } finally {
      setLoading(false);
    }
  };

  const [genProgress, setGenProgress] = useState(0);

  // Animate progress while API call is in-flight
  useEffect(() => {
    if (!loading) {
      setGenProgress(0);
      return;
    }
    setGenProgress(5);
    // Simulate incremental progress up to 90% while waiting
    const steps = [
      { target: 30, delay: 1500 },
      { target: 55, delay: 4000 },
      { target: 72, delay: 8000 },
      { target: 85, delay: 14000 },
      { target: 90, delay: 20000 },
    ];
    const timers = steps.map(({ target, delay }) =>
      setTimeout(() => setGenProgress(target), delay)
    );
    return () => timers.forEach(clearTimeout);
  }, [loading]);

  const [validationError, setValidationError] = useState("");

  const isStepValid = () => {
    if (currentStep === 1) {
      return educationLevel !== "" && subjects.length > 0 && interests.length > 0;
    }
    if (currentStep === 2) {
      return experienceLevel !== "" && learningCommitment !== "" && careerPriority !== "" && workStyle !== "";
    }
    if (currentStep === 3) {
      return stressHandling !== "" && motivationType !== "" && teamworkPreference !== "" && challengePreference !== "" && decisionMaking !== "";
    }
    return true;
  };

  const getStepValidationMessage = () => {
    if (currentStep === 1) {
      if (!educationLevel) return "Please select your education level.";
      if (subjects.length === 0) return "Please select at least one subject.";
      if (interests.length === 0) return "Please select at least one career interest.";
    }
    if (currentStep === 2) {
      if (!experienceLevel) return "Please select your experience level.";
      if (!learningCommitment) return "Please select your learning commitment.";
      if (!careerPriority) return "Please select a career priority.";
      if (!workStyle) return "Please select a preferred work style.";
    }
    if (currentStep === 3) {
      if (!stressHandling) return "Please answer Question 1.";
      if (!motivationType) return "Please answer Question 2.";
      if (!teamworkPreference) return "Please answer Question 3.";
      if (!challengePreference) return "Please answer Question 4.";
      if (!decisionMaking) return "Please answer Question 5.";
    }
    return "";
  };

  const handleNext = () => {
    if (!isStepValid()) {
      setValidationError(getStepValidationMessage());
      return;
    }
    setValidationError("");
    if (currentStep < totalSteps) {
      setCurrentStep(currentStep + 1);
    } else {
      submit({
        educationLevel, subjects, interests, performance, experienceLevel, learningCommitment, careerPriority, workStyle, additionalNotes, stressHandling, motivationType, teamworkPreference, challengePreference, decisionMaking,
      });
    }
  };

  const handleBack = () => {
    setValidationError("");
    if (currentStep > 1) {
      setCurrentStep(currentStep - 1);
    }
  };

  return (
    <div className="min-h-screen abstract-bg">
      <Navbar showHomeButton />

      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        {/* Header */}
        <div className="text-center mb-8 sm:mb-12">
          <div className="flex items-center justify-center gap-2 mb-4">
            <div className="w-12 h-12 gradient-primary rounded-xl flex items-center justify-center">
              <Brain className="w-7 h-7 text-white" />
            </div>
            <span className="text-2xl font-bold text-gradient-primary">
              EduBot
            </span>
          </div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            <TranslatedText>Let's Get to Know You</TranslatedText>
          </h1>
          <p className="text-gray-600">
            <TranslatedText>Help us understand your profile to provide personalized career recommendations</TranslatedText>
          </p>
        </div>

        {/* Progress Bar */}
        <div className="mb-10 px-4">
          {/* Step Indicators and Progress Line */}
          <div className="relative">
            {/* Background Line */}
            <div className="absolute left-0 right-0 top-[22px] h-0.5 bg-gray-200" />

            {/* Active Progress Line */}
            <div
              className="absolute left-0 top-[22px] h-0.5 bg-gradient-to-r from-indigo-500 via-purple-500 to-teal-500 transition-all duration-700 ease-out"
              style={{
                width:
                  currentStep === 1
                    ? "0%"
                    : currentStep === 2
                      ? "50%"
                      : "100%",
              }}
            />

            {/* Steps Container */}
            <div className="relative flex justify-between">
              {[
                {
                  step: 1,
                  label: "Student Profile",
                  icon: GraduationCap,
                },
                {
                  step: 2,
                  label: "Career Preferences",
                  icon: Target,
                },
                { step: 3, label: "Assessment", icon: Brain },
              ].map(({ step, label, icon: Icon }) => (
                <div
                  key={step}
                  className="flex flex-col items-center group"
                >
                  {/* Circle */}
                  <div
                    className={`relative w-11 h-11 rounded-full transition-all duration-500 flex items-center justify-center ${
                      currentStep >= step
                        ? "gradient-primary shadow-lg shadow-pink-300/50 scale-110"
                        : "bg-white border-2 border-gray-300 group-hover:border-gray-400"
                    }`}
                  >
                    {/* Content */}
                    <div className="relative z-10">
                      {currentStep > step ? (
                        <CheckCircle2
                          className="w-6 h-6 text-white"
                          strokeWidth={2.5}
                        />
                      ) : (
                        <span
                          className={`font-bold text-base ${
                            currentStep >= step
                              ? "text-white"
                              : "text-gray-400"
                          }`}
                        >
                          {step}
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Label */}
                  <div className="mt-3 text-center max-w-[120px]">
                    <p
                      className={`text-xs font-semibold transition-colors duration-300 ${
                        currentStep >= step
                          ? "text-pink-700"
                          : "text-gray-500"
                      }`}
                    >
                      {label}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Progress Percentage */}
          <div className="mt-6 flex items-center justify-center gap-3">
            <div className="flex-1 h-2 bg-gray-100 rounded-full overflow-hidden">
              <div
                className="h-full gradient-primary transition-all duration-700 ease-out rounded-full"
                style={{
                  width: `${(currentStep / totalSteps) * 100}%`,
                }}
              />
            </div>
            <span className="text-sm font-bold text-pink-700 min-w-[60px] text-right">
              {Math.round((currentStep / totalSteps) * 100)}%
            </span>
          </div>
        </div>

        {/* Form Content */}
        <div className="bg-white rounded-2xl border border-gray-200 shadow-xl p-8">
          {/* Step 1: Student Profile */}
          {currentStep === 1 && (
            <div className="space-y-8">
              <div className="flex items-center gap-3 mb-6">
                <div className="w-12 h-12 bg-indigo-100 rounded-xl flex items-center justify-center">
                  <GraduationCap className="w-6 h-6 text-indigo-600" />
                </div>
                <div>
                  <h2 className="text-2xl font-bold text-gray-900">
                    <TranslatedText>Student Profile</TranslatedText>
                  </h2>
                  <p className="text-gray-600">
                    <TranslatedText>Tell us about your academic background</TranslatedText>
                  </p>
                </div>
              </div>

              <div className="space-y-2">
                <Label htmlFor="education-level">
                  <TranslatedText>Education Level</TranslatedText>
                </Label>
                <Select
                  value={educationLevel}
                  onValueChange={setEducationLevel}
                >
                  <SelectTrigger
                    id="education-level"
                    className="h-12"
                  >
                    <SelectValue placeholder="Select your current education level" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="class-10"><TranslatedText>Class 10th</TranslatedText>
                    </SelectItem>
                    <SelectItem value="class-11"><TranslatedText>Class 11th</TranslatedText>
                    </SelectItem>
                    <SelectItem value="class-12"><TranslatedText>Class 12th</TranslatedText>
                    </SelectItem>
                    <SelectItem value="graduation"><TranslatedText>Graduation (Pursuing)</TranslatedText>
                    </SelectItem>
                    <SelectItem value="graduated"><TranslatedText>Graduated</TranslatedText>
                    </SelectItem>
                    <SelectItem value="postgrad"><TranslatedText>Post Graduation</TranslatedText>
                    </SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-3">
                <Label>
                  <TranslatedText>Subjects Studied (Select all that apply)</TranslatedText>
                </Label>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 sm:gap-3">
                  {subjectOptions.map((subject) => (
                    <button
                      key={subject}
                      onClick={() =>
                        toggleSelection(
                          subject,
                          subjects,
                          setSubjects,
                        )
                      }
                      className={`p-3 sm:p-4 rounded-lg sm:rounded-xl border-2 text-left transition-all ${
                        subjects.includes(subject)
                          ? "border-indigo-600 bg-indigo-50 text-indigo-700"
                          : "border-gray-200 hover:border-indigo-200"
                      }`}
                    >
                      <div className="flex items-center gap-2">
                        <div
                          className={`w-4 h-4 sm:w-5 sm:h-5 rounded flex-shrink-0 border-2 flex items-center justify-center ${
                            subjects.includes(subject)
                              ? "border-indigo-600 bg-indigo-600"
                              : "border-gray-300"
                          }`}
                        >
                          {subjects.includes(subject) && (
                            <CheckCircle2 className="w-3 h-3 sm:w-4 sm:h-4 text-white" />
                          )}
                        </div>
                        <span className="text-sm sm:text-base font-medium">
                          <TranslatedText>{subject}</TranslatedText>
                        </span>
                      </div>
                    </button>
                  ))}
                </div>
              </div>

              <div className="space-y-3">
                <Label>
                  <TranslatedText>Career Interests (Select your top interests)</TranslatedText>
                </Label>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 sm:gap-3">
                  {interestOptions.map((interest) => (
                    <button
                      key={interest}
                      onClick={() =>
                        toggleSelection(
                          interest,
                          interests,
                          setInterests,
                        )
                      }
                      className={`p-3 sm:p-4 rounded-lg sm:rounded-xl border-2 text-left transition-all ${
                        interests.includes(interest)
                          ? "border-purple-600 bg-purple-50 text-purple-700"
                          : "border-gray-200 hover:border-purple-200"
                      }`}
                    >
                      <div className="flex items-center gap-2">
                        <div
                          className={`w-4 h-4 sm:w-5 sm:h-5 rounded flex-shrink-0 border-2 flex items-center justify-center ${
                            interests.includes(interest)
                              ? "border-purple-600 bg-purple-600"
                              : "border-gray-300"
                          }`}
                        >
                          {interests.includes(interest) && (
                            <CheckCircle2 className="w-3 h-3 sm:w-4 sm:h-4 text-white" />
                          )}
                        </div>
                        <span className="text-sm sm:text-base font-medium">
                          <TranslatedText>{interest}</TranslatedText>
                        </span>
                      </div>
                    </button>
                  ))}
                </div>
              </div>

              <div className="space-y-4">
                <Label>
                  <TranslatedText>Academic Performance (Rate yourself: 0-10)</TranslatedText>
                </Label>
                <div className="space-y-3">
                  <Slider
                    value={performance}
                    onValueChange={setPerformance}
                    min={0}
                    max={10}
                    step={1}
                    className="py-4"
                  />
                  <div className="flex justify-between text-sm text-gray-600">
                    <span>0 <TranslatedText>(Not Started)</TranslatedText></span>
                    <span className="font-bold text-indigo-600 text-lg">
                      {performance[0]}
                    </span>
                    <span>10 <TranslatedText>(Excellent)</TranslatedText></span>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Step 2: Career Preferences */}
          {currentStep === 2 && (
            <div className="space-y-8">
              <div className="flex items-center gap-3 mb-6">
                <div className="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center">
                  <Target className="w-6 h-6 text-purple-600" />
                </div>
                <div>
                  <h2 className="text-2xl font-bold text-gray-900">
                    <TranslatedText>Career Preferences</TranslatedText>
                  </h2>
                  <p className="text-gray-600">
                    <TranslatedText>What are you looking for in your career?</TranslatedText>
                  </p>
                </div>
              </div>

              <div className="space-y-3">
                <Label><TranslatedText>Experience Level</TranslatedText></Label>
                <div className="grid grid-cols-2 gap-3">
                  {[
                    {
                      value: "beginner",
                      label: "Beginner",
                      desc: "Just starting out",
                      Icon: Target,
                    },
                    {
                      value: "some-knowledge",
                      label: "Some Knowledge",
                      desc: "Learned basics",
                      Icon: BookOpen,
                    },
                    {
                      value: "intermediate",
                      label: "Intermediate",
                      desc: "Hands-on experience",
                      Icon: Zap,
                    },
                    {
                      value: "advanced",
                      label: "Advanced",
                      desc: "Expert level",
                      Icon: Rocket,
                    },
                  ].map((option) => (
                    <button
                      key={option.value}
                      onClick={() =>
                        setExperienceLevel(option.value)
                      }
                      className={`p-4 rounded-xl border-2 text-left transition-all ${
                        experienceLevel === option.value
                          ? "border-indigo-600 bg-indigo-50"
                          : "border-gray-200 hover:border-indigo-200"
                      }`}
                    >
                      <div className="flex items-center gap-2 font-semibold text-gray-900 mb-1">
                        <option.Icon className="w-4 h-4" />
                        <TranslatedText>{option.label}</TranslatedText>
                      </div>
                      <div className="text-sm text-gray-600">
                        <TranslatedText>{option.desc}</TranslatedText>
                      </div>
                    </button>
                  ))}
                </div>
              </div>

              <div className="space-y-3">
                <Label><TranslatedText>Learning Commitment</TranslatedText></Label>
                <div className="grid grid-cols-3 gap-3">
                  {[
                    {
                      value: "part-time",
                      label: "Part-time",
                      desc: "5-10 hrs/week",
                    },
                    {
                      value: "regular",
                      label: "Regular",
                      desc: "15-20 hrs/week",
                    },
                    {
                      value: "full-time",
                      label: "Full-time",
                      desc: "30+ hrs/week",
                    },
                  ].map((option) => (
                    <button
                      key={option.value}
                      onClick={() =>
                        setLearningCommitment(option.value)
                      }
                      className={`p-4 rounded-xl border-2 text-center transition-all ${
                        learningCommitment === option.value
                          ? "border-purple-600 bg-purple-50"
                          : "border-gray-200 hover:border-purple-200"
                      }`}
                    >
                      <div className="font-semibold text-gray-900 mb-1">
                        <TranslatedText>{option.label}</TranslatedText>
                      </div>
                      <div className="text-sm text-gray-600">
                        <TranslatedText>{option.desc}</TranslatedText>
                      </div>
                    </button>
                  ))}
                </div>
              </div>

              <div className="space-y-3">
                <Label><TranslatedText>Career Priority</TranslatedText></Label>
                <RadioGroup
                  value={careerPriority}
                  onValueChange={setCareerPriority}
                >
                  {[
                    {
                      value: "high-salary",
                      label: "High Salary Package",
                    },
                    {
                      value: "work-life",
                      label: "Work-Life Balance",
                    },
                    {
                      value: "growth",
                      label: "Career Growth Opportunities",
                    },
                    {
                      value: "passion",
                      label: "Following My Passion",
                    },
                  ].map((option) => (
                    <div
                      key={option.value}
                      className={`flex items-center space-x-3 p-4 rounded-xl border-2 transition-all ${
                        careerPriority === option.value
                          ? "border-indigo-600 bg-indigo-50"
                          : "border-gray-200 hover:border-indigo-200"
                      }`}
                    >
                      <RadioGroupItem
                        value={option.value}
                        id={option.value}
                      />
                      <Label
                        htmlFor={option.value}
                        className="flex-1 cursor-pointer font-medium text-gray-900"
                      ><TranslatedText>{option.label}</TranslatedText>
                      </Label>
                    </div>
                  ))}
                </RadioGroup>
              </div>

              <div className="space-y-3">
                <Label><TranslatedText>Preferred Work Style</TranslatedText></Label>
                <RadioGroup
                  value={workStyle}
                  onValueChange={setWorkStyle}
                >
                  {[
                    {
                      value: "office",
                      label: "Office-based Work",
                    },
                    { value: "remote", label: "Remote Work" },
                    {
                      value: "hybrid",
                      label: "Hybrid (Mix of both)",
                    },
                    {
                      value: "flexible",
                      label: "Flexible (No preference)",
                    },
                  ].map((option) => (
                    <div
                      key={option.value}
                      className={`flex items-center space-x-3 p-4 rounded-xl border-2 transition-all ${
                        workStyle === option.value
                          ? "border-purple-600 bg-purple-50"
                          : "border-gray-200 hover:border-purple-200"
                      }`}
                    >
                      <RadioGroupItem
                        value={option.value}
                        id={option.value}
                      />
                      <Label
                        htmlFor={option.value}
                        className="flex-1 cursor-pointer font-medium text-gray-900"
                      ><TranslatedText>{option.label}</TranslatedText>
                      </Label>
                    </div>
                  ))}
                </RadioGroup>
              </div>

              <div className="space-y-2">
                <Label htmlFor="notes">
                  <TranslatedText>Additional Notes (Optional)</TranslatedText>
                </Label>
                <Textarea
                  id="notes"
                  placeholder="Any specific career goals, constraints, or preferences you'd like to share..."
                  value={additionalNotes}
                  onChange={(e) =>
                    setAdditionalNotes(e.target.value)
                  }
                  className="min-h-[100px]"
                />
              </div>
            </div>
          )}

          {/* Step 3: Professional Assessment */}
          {currentStep === 3 && (
            <div className="space-y-6">
              {/* Header with Icon */}
              <div className="text-center mb-6">
                <div className="w-16 h-16 gradient-primary rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-lg">
                  <Brain className="w-8 h-8 text-white" />
                </div>
                <h2 className="text-3xl font-bold text-gray-900 mb-2">
                  <TranslatedText>Psychological Career Assessment</TranslatedText>
                </h2>
                <p className="text-gray-600">
                  <TranslatedText>Answer all 5 questions to discover your unique professional personality profile</TranslatedText>
                </p>
                <p className="text-xs text-red-500 font-medium mt-1">* <TranslatedText>All questions are mandatory</TranslatedText></p>
              </div>
            
              {/* Question 1: Stress Handling */}
              <div className={`rounded-2xl p-6 border-2 transition-all ${stressHandling ? "border-pink-400 bg-pink-50/30" : "border-pink-200 bg-gradient-to-br from-pink-50/50 to-white"}`}>
                <div className="flex items-start gap-3 mb-4">
                  <div className="w-10 h-10 bg-pink-500 rounded-xl flex items-center justify-center flex-shrink-0">
                    <span className="text-white font-bold text-lg">1</span>
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="text-xl font-bold text-gray-900">
                        🎯 <TranslatedText>Facing tight deadlines with unexpected obstacles - how do you respond?</TranslatedText>
                      </h3>
                      {stressHandling ? (
                        <CheckCircle2 className="w-5 h-5 text-pink-500 flex-shrink-0" />
                      ) : (
                        <span className="text-xs text-red-500 font-semibold flex-shrink-0"><TranslatedText>* Required</TranslatedText></span>
                      )}
                    </div>
                    <p className="text-sm text-pink-700 font-medium"><TranslatedText>Reveals your stress resilience pattern</TranslatedText></p>
                  </div>
                </div>
                <RadioGroup
                  value={stressHandling}
                  onValueChange={setStressHandling}
                >
                  <div className="space-y-3">
                    {[
                      {
                        value: "calm",
                        emoji: "💪",
                        label:
                          "I thrive under pressure - my focus sharpens",
                        desc: "High-stakes roles suit you",
                        color: "pink",
                      },
                      {
                        value: "structured",
                        emoji: "📋",
                        label:
                          "I create detailed contingency plans to avoid chaos",
                        desc: "Strategic planning roles match you",
                        color: "pink",
                      },
                      {
                        value: "breaks",
                        emoji: "🔄",
                        label:
                          "I step back, recharge, then attack with fresh perspective",
                        desc: "Creative problem-solving fits you",
                        color: "pink",
                      },
                      {
                        value: "collaborative",
                        emoji: "🤝",
                        label:
                          "I rally the team - collective intelligence wins",
                        desc: "Collaborative leadership aligns with you",
                        color: "pink",
                      },
                    ].map((option) => (
                      <div
                        key={option.value}
                        onClick={() =>
                          setStressHandling(option.value)
                        }
                        className={`flex items-center gap-4 p-4 rounded-xl border-2 cursor-pointer transition-all hover:scale-[1.02] ${
                          stressHandling === option.value
                            ? "border-pink-500 bg-white shadow-lg shadow-pink-200/50"
                            : "border-gray-200 bg-white hover:border-pink-300"
                        }`}
                      >
                        <RadioGroupItem
                          value={option.value}
                          id={`stress-${option.value}`}
                          className="flex-shrink-0"
                        />
                        <div className="text-2xl flex-shrink-0">
                          {option.emoji}
                        </div>
                        <div className="flex-1 min-w-0">
                          <Label
                            htmlFor={`stress-${option.value}`}
                            className="cursor-pointer font-semibold text-gray-900 block mb-1 leading-tight"
                          ><TranslatedText>{option.label}</TranslatedText>
                          </Label>
                          <p className="text-xs text-pink-600 font-medium"><TranslatedText>{option.desc}</TranslatedText>
                          </p>
                        </div>
                      </div>
                    ))}
                  </div>
                </RadioGroup>
              </div>

              {/* Question 2: Motivation Type */}
              <div className={`rounded-2xl p-6 border-2 transition-all ${motivationType ? "border-purple-400 bg-purple-50/30" : "border-purple-200 bg-gradient-to-br from-purple-50/50 to-white"}`}>
                <div className="flex items-start gap-3 mb-4">
                  <div className="w-10 h-10 bg-purple-500 rounded-xl flex items-center justify-center flex-shrink-0">
                    <span className="text-white font-bold text-lg">2</span>
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="text-xl font-bold text-gray-900">
                        <TranslatedText>☀️ Picture your ideal Monday morning at work - what excites you most?</TranslatedText>
                      </h3>
                      {motivationType ? (
                        <CheckCircle2 className="w-5 h-5 text-purple-500 flex-shrink-0" />
                      ) : (
                        <span className="text-xs text-red-500 font-semibold flex-shrink-0"><TranslatedText>* Required</TranslatedText></span>
                      )}
                    </div>
                    <p className="text-sm text-purple-700 font-medium"><TranslatedText>Uncovers your core motivational driver</TranslatedText></p>
                  </div>
                </div>
                <RadioGroup
                  value={motivationType}
                  onValueChange={setMotivationType}
                >
                  <div className="space-y-3">
                    {[
                      {
                        value: "achievement",
                        emoji: "🎖️",
                        label:
                          "Crushing ambitious goals and seeing metrics soar",
                        desc: "Achievement-oriented careers energize you",
                        color: "purple",
                      },
                      {
                        value: "learning",
                        emoji: "🚀",
                        label:
                          "Exploring cutting-edge concepts and mastering new skills",
                        desc: "Innovation and R&D roles inspire you",
                        color: "purple",
                      },
                      {
                        value: "recognition",
                        emoji: "⭐",
                        label:
                          "Being acknowledged as the go-to expert in your field",
                        desc: "Specialist and thought leadership roles suit you",
                        color: "purple",
                      },
                      {
                        value: "impact",
                        emoji: "🌍",
                        label:
                          "Knowing your work transforms lives and communities",
                        desc: "Purpose-driven careers fulfill you",
                        color: "purple",
                      },
                    ].map((option) => (
                      <div
                        key={option.value}
                        onClick={() =>
                          setMotivationType(option.value)
                        }
                        className={`flex items-center gap-4 p-4 rounded-xl border-2 cursor-pointer transition-all hover:scale-[1.02] ${
                          motivationType === option.value
                            ? "border-purple-500 bg-white shadow-lg shadow-purple-200/50"
                            : "border-gray-200 bg-white hover:border-purple-300"
                        }`}
                      >
                        <RadioGroupItem
                          value={option.value}
                          id={`motivation-${option.value}`}
                          className="flex-shrink-0"
                        />
                        <div className="text-2xl flex-shrink-0">
                          {option.emoji}
                        </div>
                        <div className="flex-1 min-w-0">
                          <Label
                            htmlFor={`motivation-${option.value}`}
                            className="cursor-pointer font-semibold text-gray-900 block mb-1 leading-tight"
                          ><TranslatedText>{option.label}</TranslatedText>
                          </Label>
                          <p className="text-xs text-purple-600 font-medium"><TranslatedText>{option.desc}</TranslatedText>
                          </p>
                        </div>
                      </div>
                    ))}
                  </div>
                </RadioGroup>
              </div>

              {/* Question 3: Teamwork Preference */}
              <div className={`rounded-2xl p-6 border-2 transition-all ${teamworkPreference ? "border-blue-400 bg-blue-50/30" : "border-blue-200 bg-gradient-to-br from-blue-50/50 to-white"}`}>
                <div className="flex items-start gap-3 mb-4">
                  <div className="w-10 h-10 bg-blue-500 rounded-xl flex items-center justify-center flex-shrink-0">
                    <span className="text-white font-bold text-lg">3</span>
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="text-xl font-bold text-gray-900">
                        <TranslatedText>👥 You're assigned to a major project - what's your ideal working dynamic?</TranslatedText>
                      </h3>
                      {teamworkPreference ? (
                        <CheckCircle2 className="w-5 h-5 text-blue-500 flex-shrink-0" />
                      ) : (
                        <span className="text-xs text-red-500 font-semibold flex-shrink-0"><TranslatedText>* Required</TranslatedText></span>
                      )}
                    </div>
                    <p className="text-sm text-blue-700 font-medium"><TranslatedText>Determines your optimal collaboration style</TranslatedText></p>
                  </div>
                </div>
                <RadioGroup
                  value={teamworkPreference}
                  onValueChange={setTeamworkPreference}
                >
                  <div className="space-y-3">
                    {[
                      {
                        value: "team",
                        emoji: "👨‍👩‍👧‍👦",
                        label:
                          "Brainstorming sessions and collaborative energy fuel my best work",
                        desc: "Team-centric environments maximize your potential",
                        color: "blue",
                      },
                      {
                        value: "solo",
                        emoji: "🧘",
                        label:
                          "Deep focus alone lets me produce my most innovative solutions",
                        desc: "Individual contributor roles leverage your strengths",
                        color: "blue",
                      },
                      {
                        value: "balanced",
                        emoji: "⚖️",
                        label:
                          "I alternate: solo deep work + team sync sessions = perfect rhythm",
                        desc: "Hybrid collaboration models suit you best",
                        color: "blue",
                      },
                    ].map((option) => (
                      <div
                        key={option.value}
                        onClick={() =>
                          setTeamworkPreference(option.value)
                        }
                        className={`flex items-center gap-4 p-4 rounded-xl border-2 cursor-pointer transition-all hover:scale-[1.02] ${
                          teamworkPreference === option.value
                            ? "border-blue-500 bg-white shadow-lg shadow-blue-200/50"
                            : "border-gray-200 bg-white hover:border-blue-300"
                        }`}
                      >
                        <RadioGroupItem
                          value={option.value}
                          id={`teamwork-${option.value}`}
                          className="flex-shrink-0"
                        />
                        <div className="text-2xl flex-shrink-0">
                          {option.emoji}
                        </div>
                        <div className="flex-1 min-w-0">
                          <Label
                            htmlFor={`teamwork-${option.value}`}
                            className="cursor-pointer font-semibold text-gray-900 block mb-1 leading-tight"
                          ><TranslatedText>{option.label}</TranslatedText>
                          </Label>
                          <p className="text-xs text-blue-600 font-medium"><TranslatedText>{option.desc}</TranslatedText>
                          </p>
                        </div>
                      </div>
                    ))}
                  </div>
                </RadioGroup>
              </div>

              {/* Question 4: Challenge Preference */}
              <div className={`rounded-2xl p-6 border-2 transition-all ${challengePreference ? "border-fuchsia-400 bg-fuchsia-50/30" : "border-fuchsia-200 bg-gradient-to-br from-fuchsia-50/50 to-white"}`}>
                <div className="flex items-start gap-3 mb-4">
                  <div className="w-10 h-10 bg-fuchsia-500 rounded-xl flex items-center justify-center flex-shrink-0">
                    <span className="text-white font-bold text-lg">4</span>
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="text-xl font-bold text-gray-900">
                        <TranslatedText>🧩 When presented with a challenging problem - which scenario energizes you?</TranslatedText>
                      </h3>
                      {challengePreference ? (
                        <CheckCircle2 className="w-5 h-5 text-fuchsia-500 flex-shrink-0" />
                      ) : (
                        <span className="text-xs text-red-500 font-semibold flex-shrink-0"><TranslatedText>* Required</TranslatedText></span>
                      )}
                    </div>
                    <p className="text-sm text-fuchsia-700 font-medium"><TranslatedText>Reveals your cognitive preference pattern</TranslatedText></p>
                  </div>
                </div>
                <RadioGroup
                  value={challengePreference}
                  onValueChange={setChallengePreference}
                >
                  <div className="space-y-3">
                    {[
                      {
                        value: "complex",
                        emoji: "🔬",
                        label:
                          "Multi-layered puzzles that require weeks of deep analysis",
                        desc: "Complex problem-solving roles engage you",
                        color: "fuchsia",
                      },
                      {
                        value: "quick",
                        emoji: "⚡",
                        label:
                          "Rapid-fire challenges with immediate, visible wins",
                        desc: "Fast-paced execution roles energize you",
                        color: "fuchsia",
                      },
                      {
                        value: "creative",
                        emoji: "🎨",
                        label:
                          "Open-ended briefs where I can innovate freely",
                        desc: "Creative and design-thinking roles inspire you",
                        color: "fuchsia",
                      },
                      {
                        value: "defined",
                        emoji: "📐",
                        label:
                          "Clear problems with proven methodologies to optimize",
                        desc: "Process optimization roles suit your style",
                        color: "fuchsia",
                      },
                    ].map((option) => (
                      <div
                        key={option.value}
                        onClick={() =>
                          setChallengePreference(option.value)
                        }
                        className={`flex items-center gap-4 p-4 rounded-xl border-2 cursor-pointer transition-all hover:scale-[1.02] ${
                          challengePreference === option.value
                            ? "border-fuchsia-500 bg-white shadow-lg shadow-fuchsia-200/50"
                            : "border-gray-200 bg-white hover:border-fuchsia-300"
                        }`}
                      >
                        <RadioGroupItem
                          value={option.value}
                          id={`challenge-${option.value}`}
                          className="flex-shrink-0"
                        />
                        <div className="text-2xl flex-shrink-0">
                          {option.emoji}
                        </div>
                        <div className="flex-1 min-w-0">
                          <Label
                            htmlFor={`challenge-${option.value}`}
                            className="cursor-pointer font-semibold text-gray-900 block mb-1 leading-tight"
                          ><TranslatedText>{option.label}</TranslatedText>
                          </Label>
                          <p className="text-xs text-fuchsia-600 font-medium"><TranslatedText>{option.desc}</TranslatedText>
                          </p>
                        </div>
                      </div>
                    ))}
                  </div>
                </RadioGroup>
              </div>

              {/* Question 5: Decision Making */}
              <div className={`rounded-2xl p-6 border-2 transition-all ${decisionMaking ? "border-indigo-400 bg-indigo-50/30" : "border-indigo-200 bg-gradient-to-br from-indigo-50/50 to-white"}`}>
                <div className="flex items-start gap-3 mb-4">
                  <div className="w-10 h-10 bg-indigo-500 rounded-xl flex items-center justify-center flex-shrink-0">
                    <span className="text-white font-bold text-lg">5</span>
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="text-xl font-bold text-gray-900">
                        <TranslatedText>🎲 A critical decision needs to be made by end of day - how do you approach it?</TranslatedText>
                      </h3>
                      {decisionMaking ? (
                        <CheckCircle2 className="w-5 h-5 text-indigo-500 flex-shrink-0" />
                      ) : (
                        <span className="text-xs text-red-500 font-semibold flex-shrink-0"><TranslatedText>* Required</TranslatedText></span>
                      )}
                    </div>
                    <p className="text-sm text-indigo-700 font-medium"><TranslatedText>Identifies your decision-making framework</TranslatedText></p>
                  </div>
                </div>
                <RadioGroup
                  value={decisionMaking}
                  onValueChange={setDecisionMaking}
                >
                  <div className="space-y-3">
                    {[
                      {
                        value: "data",
                        emoji: "📊",
                        label:
                          "I dive into analytics, metrics, and statistical models",
                        desc: "Data-driven analytical roles match your approach",
                        color: "indigo",
                      },
                      {
                        value: "intuitive",
                        emoji: "💡",
                        label:
                          "I trust my instinct honed by experience and pattern recognition",
                        desc: "Strategic and visionary roles align with you",
                        color: "indigo",
                      },
                      {
                        value: "collaborative",
                        emoji: "🗣️",
                        label:
                          "I gather diverse perspectives before synthesizing the best path",
                        desc: "Consensus-building leadership suits you",
                        color: "indigo",
                      },
                      {
                        value: "quick",
                        emoji: "⏱️",
                        label:
                          "I assess rapidly, commit decisively, and adjust as needed",
                        desc: "Agile and startup environments fit your style",
                        color: "indigo",
                      },
                    ].map((option) => (
                      <div
                        key={option.value}
                        onClick={() =>
                          setDecisionMaking(option.value)
                        }
                        className={`flex items-center gap-4 p-4 rounded-xl border-2 cursor-pointer transition-all hover:scale-[1.02] ${
                          decisionMaking === option.value
                            ? "border-indigo-500 bg-white shadow-lg shadow-indigo-200/50"
                            : "border-gray-200 bg-white hover:border-indigo-300"
                        }`}
                      >
                        <RadioGroupItem
                          value={option.value}
                          id={`decision-${option.value}`}
                          className="flex-shrink-0"
                        />
                        <div className="text-2xl flex-shrink-0">
                          {option.emoji}
                        </div>
                        <div className="flex-1 min-w-0">
                          <Label
                            htmlFor={`decision-${option.value}`}
                            className="cursor-pointer font-semibold text-gray-900 block mb-1 leading-tight"
                          ><TranslatedText>{option.label}</TranslatedText>
                          </Label>
                          <p className="text-xs text-indigo-600 font-medium"><TranslatedText>{option.desc}</TranslatedText>
                          </p>
                        </div>
                      </div>
                    ))}
                  </div>
                </RadioGroup>
              </div>

              {/* Completion Message */}
              <div className="text-center gradient-primary rounded-2xl p-6 text-white">
                <div className="flex items-center justify-center gap-2 mb-2">
                  <Sparkles className="w-5 h-5" />
                  <p className="font-bold text-lg"><TranslatedText>Almost There!</TranslatedText>
                  </p>
                  <Sparkles className="w-5 h-5" />
                </div>
                <p className="text-sm text-pink-100">
                  <TranslatedText>Click "Get Recommendations" to discover your
                  personalized career matches based on your
                  unique profile</TranslatedText>
                </p>
              </div>
            </div>
          )}

          {/* Validation Error Banner */}
          {validationError && (
            <div className="mt-6 p-4 bg-amber-50 border border-amber-300 rounded-xl text-amber-800 text-sm font-medium flex items-center gap-2">
              <span>⚠️</span> {validationError}
            </div>
          )}

          {/* Error Banner */}
          {error && (
            <div className="mt-6 p-4 bg-red-50 border border-red-200 rounded-xl text-red-700 text-sm">
              {error}
            </div>
          )}

          {/* Navigation Buttons */}
          <div className="flex justify-between mt-8 pt-6 border-t border-gray-200">
            <Button
              type="button"
              variant="outline"
              onClick={handleBack}
              disabled={currentStep === 1}
              className="px-6"
            >
              <ArrowLeft className="w-4 h-4 mr-2" />
              <TranslatedText>Back</TranslatedText>
            </Button>
            <Button
              type="button"
              onClick={handleNext}
              disabled={loading}
              className="gradient-primary hover:opacity-90 transition-opacity px-6 disabled:opacity-60"
            >
              {loading ? (
                <>
                  <span className="w-4 h-4 mr-2 border-2 border-white border-t-transparent rounded-full animate-spin inline-block" />
                  <TranslatedText>Generating...</TranslatedText> {genProgress}%
                </>
              ) : currentStep === totalSteps ? (
                <>
                  <TranslatedText>Get Recommendations</TranslatedText>
                  <CheckCircle2 className="w-4 h-4 ml-2" />
                </>
              ) : (
                <>
                  <TranslatedText>Continue</TranslatedText>
                  <ArrowRight className="w-4 h-4 ml-2" />
                </>
              )}
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}