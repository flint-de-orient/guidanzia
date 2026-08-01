import { useState } from 'react';
import { useSearchParams, useNavigate} from 'react-router';
import { Button } from '../components/ui/button';
import { Card } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { CreditCard, Lock, ArrowLeft, Check } from 'lucide-react';
import { Navbar } from '../components/navbar';

// Session management function
const clearSession = () => {
  const keysToRemove = [];
  for (let i = 0; i < sessionStorage.length; i++) {
    const key = sessionStorage.key(i);
    if (key && (key === 'careerRecommendations' || key === 'userProfile' || key.startsWith('jobDetail_'))) {
      keysToRemove.push(key);
    }
  }
  keysToRemove.forEach((k) => sessionStorage.removeItem(k));
};
export function Payment() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const jobIndex = searchParams.get('job') ?? '0';
  const [formData, setFormData] = useState({
    cardNumber: '',
    cardName: '',
    expiryDate: '',
    cvv: '',
  });

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    // Prototype only - no actual payment processing
    navigate(`/role/job-${jobIndex}`);
  };

  return (
    <div className="min-h-screen abstract-bg">
      <Navbar />

      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        {/* Back Button */}
        <button
          onClick={() => navigate(-1)}
          className="flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-6"
        >
          <ArrowLeft className="w-4 h-4" />
          Back
        </button>

        <div className="grid md:grid-cols-2 gap-8">
          {/* Payment Form */}
          <div>
            <h1 className="text-3xl font-bold text-gray-900 mb-2">Payment Details</h1>
            <p className="text-gray-600 mb-6">Complete your purchase to unlock career insights</p>

            <Card className="p-6">
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <Label htmlFor="cardNumber">Card Number</Label>
                  <div className="relative">
                    <Input
                      id="cardNumber"
                      name="cardNumber"
                      type="text"
                      placeholder="1234 5678 9012 3456"
                      value={formData.cardNumber}
                      onChange={handleInputChange}
                      maxLength={19}
                      className="pl-10"
                    />
                    <CreditCard className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                  </div>
                </div>

                <div>
                  <Label htmlFor="cardName">Cardholder Name</Label>
                  <Input
                    id="cardName"
                    name="cardName"
                    type="text"
                    placeholder="John Doe"
                    value={formData.cardName}
                    onChange={handleInputChange}
                  />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <Label htmlFor="expiryDate">Expiry Date</Label>
                    <Input
                      id="expiryDate"
                      name="expiryDate"
                      type="text"
                      placeholder="MM/YY"
                      value={formData.expiryDate}
                      onChange={handleInputChange}
                      maxLength={5}
                    />
                  </div>
                  <div>
                    <Label htmlFor="cvv">CVV</Label>
                    <Input
                      id="cvv"
                      name="cvv"
                      type="text"
                      placeholder="123"
                      value={formData.cvv}
                      onChange={handleInputChange}
                      maxLength={3}
                    />
                  </div>
                </div>

                <div className="flex items-center gap-2 text-sm text-gray-600 bg-gray-50 p-3 rounded-lg">
                  <Lock className="w-4 h-4" />
                  <span>Your payment information is secure and encrypted</span>
                </div>

                <Button
                  type="submit"
                  className="w-full bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700"
                  size="lg"
                >
                  Pay Now
                </Button>
              </form>
            </Card>
          </div>

          {/* Order Summary */}
          <div>
            <h2 className="text-2xl font-bold text-gray-900 mb-6">Order Summary</h2>

            <Card className="p-6 mb-6">
              <div className="space-y-4">
                <div>
                  <h3 className="font-semibold text-gray-900 mb-2">Career Guidance Premium</h3>
                  <p className="text-sm text-gray-600">Unlock detailed career insights and roadmaps</p>
                </div>

                <div className="border-t pt-4 space-y-2">
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-600">Subtotal</span>
                    <span className="font-medium">₹499</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-600">Tax (18%)</span>
                    <span className="font-medium">₹90</span>
                  </div>
                  <div className="border-t pt-2 flex justify-between">
                    <span className="font-bold text-gray-900">Total</span>
                    <span className="font-bold text-indigo-600 text-xl">₹589</span>
                  </div>
                </div>
              </div>
            </Card>

            <Card className="p-6 bg-gradient-to-br from-indigo-50 to-purple-50 border-indigo-200">
              <h3 className="font-semibold text-gray-900 mb-3">What's Included:</h3>
              <ul className="space-y-2">
                {[
                  'Detailed career pathway',
                  'Skills & learning resources',
                  '90-day roadmap',
                  'Top institutes list',
                  'Scholarship information',
                  'Job market analysis',
                  'Salary growth insights',
                  'Industry expert advice',
                ].map((item, index) => (
                  <li key={index} className="flex items-center gap-2 text-sm text-gray-700">
                    <Check className="w-4 h-4 text-indigo-600" />
                    {item}
                  </li>
                ))}
              </ul>
            </Card>
          </div>
        </div>
      </main>
    </div>
  );
}
