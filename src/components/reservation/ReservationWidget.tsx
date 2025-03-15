import React, { useState, useRef } from 'react';
import { Calendar, Clock, Users, Package, CheckCircle } from 'lucide-react';
import DatePicker from './DatePicker';
import EquipmentSelector from './EquipmentSelector';
import PersonalInfoForm from '../forms/PersonalInfoForm';
import Summary from '../ui/Summary';
import CollapsibleSummary from '../ui/CollapsibleSummary';

const STEPS = [
  { id: 'equipment', label: 'Wybierz sprzęt', icon: Package },
  { id: 'dates', label: 'Wybierz datę', icon: Calendar },
  { id: 'personal', label: 'Dane osobowe', icon: Users },
  { id: 'summary', label: 'Podsumowanie', icon: CheckCircle },
];

const ReservationWidget = () => {
  const [currentStep, setCurrentStep] = useState(0);
  const [highestStepReached, setHighestStepReached] = useState(0);
  const [isPersonalInfoValid, setIsPersonalInfoValid] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const summaryRef = useRef(null);
  const [reservation, setReservation] = useState({
    startDate: null,
    endDate: null,
    startTime: null,
    endTime: null,
    equipment: [],
    personalInfo: {
      firstName: '',
      lastName: '',
      email: '',
      phone: '',
      comment: '',
      termsAccepted: false
    },
  });

  const updateReservation = (field, value) => {
    setReservation(prev => ({
      ...prev,
      [field]: value,
    }));
  };

  const handleRemoveItem = (itemId) => {
    updateReservation('equipment', 
      reservation.equipment.filter(item => item.id !== itemId)
    );
  };

  const handleRemoveAllItems = () => {
    updateReservation('equipment', []);
  };

  const isStepComplete = (stepIndex) => {
    switch (stepIndex) {
      case 0:
        return reservation.equipment.length > 0;
      case 1:
        return reservation.startDate && reservation.endDate && reservation.startTime && reservation.endTime;
      case 2:
        return isPersonalInfoValid;
      case 3:
        return true;
      default:
        return false;
    }
  };

  const canNavigateToStep = (stepIndex) => {
    if (stepIndex <= highestStepReached) {
      return Array.from({ length: stepIndex }, (_, i) => i)
        .every(step => isStepComplete(step));
    }
    return false;
  };

  const nextStep = () => {
    if (currentStep < STEPS.length - 1 && isStepComplete(currentStep)) {
      const nextStepIndex = currentStep + 1;
      setCurrentStep(nextStepIndex);
      setHighestStepReached(Math.max(highestStepReached, nextStepIndex));
    }
  };

  const prevStep = () => {
    if (currentStep > 0) {
      setCurrentStep(currentStep - 1);
    }
  };

  const handleStepClick = (stepIndex) => {
    if (canNavigateToStep(stepIndex)) {
      setCurrentStep(stepIndex);
    }
  };

  const handleSubmitSuccess = () => {
    setIsSubmitting(false);
  };

  const renderStepContent = () => {
    switch (currentStep) {
      case 0:
        return (
          <EquipmentSelector 
            selectedEquipment={reservation.equipment}
            onChange={(equipment) => updateReservation('equipment', equipment)}
            onNext={nextStep}
          />
        );
      case 1:
        return (
          <DatePicker 
            startDate={reservation.startDate} 
            endDate={reservation.endDate} 
            startTime={reservation.startTime}
            endTime={reservation.endTime}
            selectedEquipment={reservation.equipment}
            onChange={(startDate, endDate, startTime, endTime) => {
              updateReservation('startDate', startDate);
              updateReservation('endDate', endDate);
              updateReservation('startTime', startTime);
              updateReservation('endTime', endTime);
            }} 
          />
        );
      case 2:
        return (
          <PersonalInfoForm 
            personalInfo={reservation.personalInfo}
            onValidityChange={setIsPersonalInfoValid}
            onChange={(personalInfo) => updateReservation('personalInfo', personalInfo)}
          />
        );
      case 3:
        return (
          <Summary 
            ref={summaryRef}
            reservation={reservation}
            onSubmit={handleSubmitSuccess}
          />
        );
      default:
        return null;
    }
  };

  const handleFinalSubmit = () => {
    if (summaryRef.current && summaryRef.current.handleSubmitReservation) {
      setIsSubmitting(true);
      summaryRef.current.handleSubmitReservation();
    }
  };

  const isCurrentStepValid = () => {
    if (currentStep === STEPS.length - 1) {
      return Array.from({ length: STEPS.length - 1 }, (_, i) => i)
        .every(step => isStepComplete(step));
    }
    return isStepComplete(currentStep);
  };

  return (
    <div className="bg-white rounded-lg shadow-lg overflow-hidden">
      {/* Progress Steps */}
      <div className="flex border-b">
        {STEPS.map((step, index) => {
          const StepIcon = step.icon;
          const isActive = index === currentStep;
          const isCompleted = index < currentStep && isStepComplete(index);
          const isAvailable = canNavigateToStep(index);
          const isDisabled = !isAvailable;

          return (
            <button 
              key={step.id}
              className={`
                flex-1 py-4 px-2 text-center border-r last:border-r-0 transition-colors
                ${isDisabled ? 'cursor-not-allowed opacity-50' : 'cursor-pointer'}
                ${isActive ? 'bg-orange-50 text-solrent-orange' : ''}
                ${isCompleted ? 'bg-green-50 text-green-600' : ''}
                ${!isActive && !isCompleted ? 'text-gray-400' : ''}
                ${isAvailable && !isActive ? 'hover:bg-gray-50' : ''}
              `}
              onClick={() => handleStepClick(index)}
              disabled={isDisabled}
            >
              <div className="flex flex-col items-center justify-center">
                <StepIcon className={`w-6 h-6 mb-1 ${isCompleted ? 'text-green-600' : ''}`} />
                <span className="text-sm font-medium hidden sm:block">{step.label}</span>
              </div>
            </button>
          );
        })}
      </div>

      {/* Content */}
      <div className={`p-6 ${currentStep !== 3 ? 'pb-32 md:pb-40' : ''}`}>
        {renderStepContent()}
      </div>

      {/* Collapsible Summary */}
      <CollapsibleSummary
        reservation={reservation}
        onRemoveItem={handleRemoveItem}
        onRemoveAll={handleRemoveAllItems}
        currentStep={currentStep}
        onNext={nextStep}
        onPrev={prevStep}
      />

      {/* Navigation */}
      <div className="px-6 py-4 bg-gray-50 flex justify-between">
        <button
          onClick={prevStep}
          disabled={currentStep === 0}
          className={`px-4 py-2 rounded ${
            currentStep === 0 
              ? 'bg-gray-200 text-gray-400 cursor-not-allowed' 
              : 'bg-gray-200 text-solrent-gray hover:bg-gray-300'
          }`}
        >
          Wstecz
        </button>
        <button
          onClick={currentStep === STEPS.length - 1 ? handleFinalSubmit : nextStep}
          disabled={!isCurrentStepValid() || isSubmitting}
          className={`px-4 py-2 rounded ${
            (!isCurrentStepValid() || isSubmitting)
              ? 'bg-orange-300 text-white cursor-not-allowed' 
              : 'bg-solrent-orange text-white hover:bg-orange-700'
          }`}
        >
          {currentStep === STEPS.length - 1 ? 'Potwierdź rezerwację' : 'Dalej'}
        </button>
      </div>
    </div>
  );
};

export default ReservationWidget;