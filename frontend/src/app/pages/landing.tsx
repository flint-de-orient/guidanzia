import { Link } from 'react-router';
import { Button } from '../components/ui/button';
import {Brain, Sparkles, Target, Award, Users, BookOpen, GraduationCap, Lightbulb, CheckCircle2, ArrowRight, Star, BarChart3
} from 'lucide-react';
import { Navbar } from '../components/navbar';
import { TranslatedText } from '../components/TranslatedText';

export function Landing() {
  return (
    <div className="min-h-screen abstract-bg">
      <Navbar />

      {/* Hero Section */}
      <section className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <div className="text-center max-w-4xl mx-auto">
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-indigo-100 to-teal-100 text-indigo-700 rounded-full text-sm font-semibold mb-6">
              <Sparkles className="w-4 h-4" />
              <TranslatedText>AI-Powered Career Guidance</TranslatedText>
            </div>
            <h1 className="text-5xl sm:text-6xl lg:text-7xl font-bold text-gray-900 mb-6">
              <TranslatedText>Discover Your Ideal</TranslatedText>
              <br />
              <span className="bg-gradient-to-r from-indigo-600 via-purple-600 to-teal-500 bg-clip-text text-transparent">
                <TranslatedText>Career Path with AI</TranslatedText>
              </span>
            </h1>
            <p className="text-xl text-gray-600 mb-8 max-w-2xl mx-auto">
              <TranslatedText>Get personalized career recommendations powered by advanced AI analysis of your interests, academic profile, and personality. Start your journey to a fulfilling career today.</TranslatedText>
            </p>
            <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
              <Link to="/signup">
                <Button
                  size="lg"
                  className="gradient-primary hover:opacity-90 transition-opacity text-lg px-8 py-6"
                >
                  <TranslatedText>Get Started Free</TranslatedText>
                  <ArrowRight className="w-5 h-5 ml-2" />
                </Button>
              </Link>

            </div>
          </div>

          {/* Feature Cards Preview */}
          <div className="grid md:grid-cols-3 gap-6 mt-16 max-w-5xl mx-auto">
            {[
              {
                icon: Brain,
                title: 'AI Analysis',
                description: 'Advanced algorithms analyze your profile',
              },
              {
                icon: Target,
                title: 'Personalized Roadmaps',
                description: '90-day plans tailored to your goals',
              },
              {
                icon: Award,
                title: 'Expert Insights',
                description: 'Learn from industry professionals',
              },
            ].map((feature, index) => (
              <div
                key={index}
                className="bg-white rounded-2xl p-6 border border-gray-200 hover:shadow-lg transition-all hover:border-purple-200"
              >
                <div className="w-14 h-14 bg-gradient-to-br from-indigo-100 to-teal-100 rounded-xl flex items-center justify-center mb-4">
                  <feature.icon className="w-7 h-7 text-indigo-600" />
                </div>
                <h3 className="text-xl font-bold text-gray-900 mb-2"><TranslatedText>{feature.title}</TranslatedText></h3>
                <p className="text-gray-600"><TranslatedText>{feature.description}</TranslatedText></p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* How It Works */}
      <section className="py-20 px-4 sm:px-6 lg:px-8 bg-white">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-4xl font-bold text-gray-900 mb-4"><TranslatedText>How It Works</TranslatedText></h2>
            <p className="text-xl text-gray-600">
              <TranslatedText>Your personalized career journey in 3 simple steps</TranslatedText>
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8 max-w-6xl mx-auto">
            {[
              {
                step: '1',
                title: 'Complete Assessment',
                description:
                  'Answer questions about your education, interests, skills, and career preferences through our intelligent assessment',
                Icon: GraduationCap,
                bgGradient: 'from-indigo-500 to-purple-600',
                shadow: 'shadow-indigo-200',
                emojiBg: 'bg-indigo-100',
              },
              {
                step: '2',
                title: 'AI-Powered Analysis',
                description:
                  'Our advanced AI engine analyzes your profile and matches you with the best career paths tailored to your strengths',
                Icon: Brain,
                bgGradient: 'from-purple-600 to-purple-700',
                shadow: 'shadow-purple-200',
                emojiBg: 'bg-purple-100',
              },
              {
                step: '3',
                title: 'Get Your Roadmap',
                description:
                  'Receive personalized career recommendations with detailed roadmaps, skills, institutes, and salary insights',
                Icon: Target,
                bgGradient: 'from-teal-500 to-teal-600',
                shadow: 'shadow-teal-200',
                emojiBg: 'bg-teal-100',
              },
            ].map((item, index) => (
              <div key={index} className="relative group">
                <div className="bg-gradient-to-br from-white via-gray-50 to-indigo-50/30 rounded-2xl p-8 border-2 border-gray-200 hover:border-indigo-300 transition-all duration-300 hover:shadow-xl h-full">
                  {/* Step Number Badge */}
                  <div className={`inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-br ${item.bgGradient} text-white mb-6 shadow-lg ${item.shadow}`}>
                    <span className="text-2xl font-bold">{item.step}</span>
                  </div>
                  
                  {/* Icon */}
                  <div className={`w-14 h-14 ${item.emojiBg} rounded-xl flex items-center justify-center mb-4`}>
                    <item.Icon className="w-7 h-7 text-gray-700" />
                  </div>
                  
                  <h3 className="text-2xl font-bold text-gray-900 mb-3"><TranslatedText>{item.title}</TranslatedText></h3>
                  <p className="text-gray-600 leading-relaxed"><TranslatedText>{item.description}</TranslatedText></p>
                  
                  {/* Checkmark Indicator */}
                  <div className="mt-6 flex items-center gap-2 text-sm font-medium text-indigo-600">
                    <CheckCircle2 className="w-5 h-5" />
                    <span><TranslatedText>Quick & Easy</TranslatedText></span>
                  </div>
                </div>
                
                {/* Connector Arrow */}
                {index < 2 && (
                  <div className="hidden md:block absolute top-1/2 -right-4 transform -translate-y-1/2 z-10">
                    <ArrowRight className="w-8 h-8 text-indigo-400" />
                  </div>
                )}
              </div>
            ))}
          </div>
          
          {/* CTA below steps */}
          <div className="text-center mt-12">
            <Link to="/onboarding">
              <Button size="lg" className="gradient-primary hover:opacity-90 transition-opacity text-lg px-8">
                <TranslatedText>Get Started Now</TranslatedText>
                <span className="text-2xl ml-2">→</span>
              </Button>
            </Link>
          </div>
        </div>
      </section>

      {/* Features Overview */}
      <section className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-12">
            <h2 className="text-4xl font-bold text-gray-900 mb-4"><TranslatedText>Everything You Need</TranslatedText></h2>
            <p className="text-xl text-gray-600"><TranslatedText>Comprehensive career guidance platform</TranslatedText></p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[
              {
                icon: Target,
                title: 'Career Recommendations',
                description: 'AI-powered suggestions for core, specialized, and interdisciplinary roles',
              },
              {
                icon: BookOpen,
                title: 'Learning Roadmaps',
                description: '90-day plans with actionable tasks and progress tracking',
              },
              {
                icon: BarChart3,
                title: 'Salary Insights',
                description: 'Detailed salary progression and city-wise comparisons',
              },
              {
                icon: Award,
                title: 'Top Institutes',
                description: 'Curated list of government, private, and online institutions',
              },
              {
                icon: Lightbulb,
                title: 'Skills Guidance',
                description: 'Must-have, core, and bonus skills with learning resources',
              },
              {
                icon: Users,
                title: 'Industry Experts',
                description: 'Advice from professionals in your target career',
              },
            ].map((feature, index) => (
              <div
                key={index}
                className="bg-white border border-gray-200 rounded-2xl p-6 hover:shadow-lg transition-all hover:border-purple-200"
              >
                <div className="w-12 h-12 bg-gradient-to-br from-indigo-100 to-teal-100 rounded-xl flex items-center justify-center mb-4">
                  <feature.icon className="w-7 h-7 text-indigo-700" />
                </div>
                <h3 className="text-xl font-bold text-gray-900 mb-2"><TranslatedText>{feature.title}</TranslatedText></h3>
                <p className="text-gray-600"><TranslatedText>{feature.description}</TranslatedText></p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Testimonials */}
      <section className="py-20 px-4 sm:px-6 lg:px-8 bg-white">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-12">
            <h2 className="text-4xl font-bold text-gray-900 mb-4"><TranslatedText>Student Success Stories</TranslatedText></h2>
            <p className="text-xl text-gray-600">
              <TranslatedText>Join thousands of students who found their perfect career path</TranslatedText>
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-6">
            {[
              {
                name: 'Rahul Sharma',
                role: 'Data Analyst at Flipkart',
                image: '👨‍💼',
                content:
                  'EduBot helped me discover my passion for data analytics. The roadmap was so clear and actionable!',
                rating: 5,
              },
              {
                name: 'Priya Patel',
                role: 'Software Engineer at TCS',
                image: '👩‍💻',
                content:
                  'The AI recommendations were spot-on. I found a career I never knew existed but absolutely love.',
                rating: 5,
              },
              {
                name: 'Arjun Kumar',
                role: 'ML Engineer at Amazon',
                image: '👨‍🔬',
                content:
                  'From confused student to confident professional. EduBot made all the difference in my journey.',
                rating: 5,
              },
            ].map((testimonial, index) => (
              <div
                key={index}
                className="gradient-soft border border-gray-200 rounded-2xl p-6"
              >
                <div className="flex items-center gap-1 mb-4">
                  {[...Array(testimonial.rating)].map((_, i) => (
                    <Star key={i} className="w-5 h-5 text-yellow-500 fill-yellow-500" />
                  ))}
                </div>
                <p className="text-gray-700 mb-6 italic">"<TranslatedText>{testimonial.content}</TranslatedText>"</p>
                <div className="flex items-center gap-3">
                  <div className="text-4xl">{testimonial.image}</div>
                  <div>
                    <p className="font-bold text-gray-900"><TranslatedText>{testimonial.name}</TranslatedText></p>
                    <p className="text-sm text-gray-600">{testimonial.role}</p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-5xl mx-auto">
          <div className="gradient-primary rounded-3xl p-12 text-center text-white">
            <h2 className="text-4xl font-bold mb-4"><TranslatedText>Ready to Discover Your Career Path?</TranslatedText></h2>
            <p className="text-xl mb-8 text-purple-100">
              <TranslatedText>Join thousands of students who have found their perfect career with EduBot</TranslatedText>
            </p>
            <Link to="/signup">
              <Button
                size="lg"
                className="bg-white text-purple-600 hover:bg-gray-100 text-lg px-8 py-6"
              ><TranslatedText>Get Started Free</TranslatedText>
                <span className="text-2xl ml-2">→</span>
              </Button>
            </Link>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-gray-900 text-gray-300 py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <div className="grid md:grid-cols-4 gap-8">
            <div>
              <div className="flex items-center gap-2 mb-4">
                <div className="w-8 h-8 gradient-primary rounded-lg flex items-center justify-center">
                  <Brain className="w-5 h-5 text-white" />
                </div>
                <span className="text-xl font-bold text-white">EduBot</span>
              </div>
              <p className="text-gray-400">AI-powered career guidance for students</p>
            </div>
            <div>
              <h3 className="font-bold text-white mb-4">Product</h3>
              <ul className="space-y-2">
                <li>
                  <a href="#" className="hover:text-white transition-colors">
                    Features
                  </a>
                </li>
                <li>
                  <a href="#" className="hover:text-white transition-colors">
                    Pricing
                  </a>
                </li>
                <li>
                  <a href="#" className="hover:text-white transition-colors">
                    Testimonials
                  </a>
                </li>
              </ul>
            </div>
            <div>
              <h3 className="font-bold text-white mb-4">Company</h3>
              <ul className="space-y-2">
                <li>
                  <a href="#" className="hover:text-white transition-colors">
                    About Us
                  </a>
                </li>
                <li>
                  <a href="#" className="hover:text-white transition-colors">
                    Careers
                  </a>
                </li>
                <li>
                  <a href="#" className="hover:text-white transition-colors">
                    Contact
                  </a>
                </li>
              </ul>
            </div>
            <div>
              <h3 className="font-bold text-white mb-4">Legal</h3>
              <ul className="space-y-2">
                <li>
                  <a href="#" className="hover:text-white transition-colors">
                    Privacy Policy
                  </a>
                </li>
                <li>
                  <a href="#" className="hover:text-white transition-colors">
                    Terms of Service
                  </a>
                </li>
              </ul>
            </div>
          </div>
          <div className="border-t border-gray-800 mt-8 pt-8 text-center text-gray-400">
            <p>&copy; 2026 EduBot. All rights reserved.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}