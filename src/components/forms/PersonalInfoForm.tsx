import React, { useState } from 'react';
import { User, Mail, Phone, ChevronDown } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

interface ValidationError {
  field: string;
  message: string;
}

interface ValidationError {
  field: string;
  message: string;
}

const PersonalInfoForm = ({ personalInfo, onChange, onValidityChange }) => {
  const [showFullInfo, setShowFullInfo] = useState(false);
  const [validationErrors, setValidationErrors] = React.useState<ValidationError[]>([]);
  const [checkboxErrors, setCheckboxErrors] = React.useState<Record<string, string>>({});
  const [touchedFields, setTouchedFields] = React.useState<Set<string>>(new Set());
  const [showCompanyData, setShowCompanyData] = useState(false);

  const validateField = (name: string, value: string): string | null => {
    switch (name) {
      case 'firstName':
        if (value.length > 50) {
          return 'Imię nie może być dłuższe niż 50 znaków';
        }
        if (!value.trim()) {
          return `Pole ${name === 'firstName' ? 'Imię' : 'Nazwisko'} jest wymagane`;
        }
        if (!/^[A-Za-zĄąĆćĘęŁłŃńÓóŚśŹźŻż\s-]+$/.test(value)) {
          return 'Dozwolone są tylko litery, spacje i myślniki';
        }
        return null;

      case 'lastName':
        if (value.length > 50) {
          return 'Nazwisko nie może być dłuższe niż 50 znaków';
        }
        if (!value.trim()) {
          return `Pole ${name === 'firstName' ? 'Imię' : 'Nazwisko'} jest wymagane`;
        }
        if (!/^[A-Za-zĄąĆćĘęŁłŃńÓóŚśŹźŻż\s-]+$/.test(value)) {
          return 'Dozwolone są tylko litery, spacje i myślniki';
        }
        return null;

      case 'email':
        if (!value.trim()) {
          return 'Adres email jest wymagany';
        }
        if (!/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.test(value)) {
          return 'Proszę wprowadzić poprawny adres email (np. jan.kowalski@example.com)';
        }
        return null;

      case 'phone':
        if (!value.trim()) {
          return 'Numer telefonu jest wymagany';
        }
        if (!/^\d{3}\s?\d{3}\s?\d{3}$/.test(value.replace(/\s/g, ''))) {
          return 'Proszę wprowadzić poprawny 9-cyfrowy numer telefonu (np. 123 456 789)';
        }
        return null;

      case 'companyNip':
        if (value && !/^\d{3}-\d{3}-\d{2}-\d{2}$/.test(value.replace(/[^0-9-]/g, ''))) {
          return 'Nieprawidłowy format NIP (XXX-XXX-XX-XX)';
        }
        return null;

      case 'companyPostalCode':
        if (value && !/^\d{2}-\d{3}$/.test(value.replace(/[^0-9-]/g, ''))) {
          return 'Nieprawidłowy format kodu pocztowego (XX-XXX)';
        }
        return null;

      case 'comment':
        if (value.length > 500) {
          return 'Komentarz nie może przekraczać 500 znaków';
        }
        return null;

      default:
        return null;
    }
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    
    let validatedValue = value;
    
    if (name === 'firstName' || name === 'lastName') {
      validatedValue = value.replace(/[0-9]/g, '');
    } else if (name === 'email') {
      validatedValue = value;
    } else if (name === 'phone') {
      const numbers = value.replace(/[^0-9]/g, '').slice(0, 9);
      validatedValue = numbers.replace(/(\d{3})(?=\d)/g, '$1 ');
    } else if (name === 'companyNip') {
      // Format NIP as XXX-XXX-XX-XX
      const numbers = value.replace(/[^0-9]/g, '').slice(0, 10);
      validatedValue = numbers.replace(/(\d{3})(\d{3})(\d{2})(\d{2})/, '$1-$2-$3-$4');
    } else if (name === 'companyPostalCode') {
      // Format postal code as XX-XXX
      const numbers = value.replace(/[^0-9]/g, '').slice(0, 5);
      validatedValue = numbers.replace(/(\d{2})(\d{3})/, '$1-$2');
    } else {
      validatedValue = value;
    }
    
    const updatedInfo = {
      ...personalInfo,
      [name]: validatedValue
    };
    
    onChange(updatedInfo);
    
    // Validate field
    const error = validateField(name, validatedValue);
    setValidationErrors(prev => {
      const newErrors = prev.filter(err => err.field !== name);
      if (error) {
        newErrors.push({ field: name, message: error });
      }
      return newErrors;
    });
    
    onValidityChange(isFormValid(updatedInfo));
  };

  const handleBlur = (e) => {
    const { name } = e.target;
    setTouchedFields(prev => new Set(prev).add(name));
  };

  const handleTermsChange = (e) => {
    const { name, checked } = e.target;
    
    // Usuń błąd dla tego checkboxa
    setCheckboxErrors(prev => {
      const newErrors = { ...prev };
      delete newErrors[name];
      return newErrors;
    });

    const updatedInfo = {
      ...personalInfo,
      [name]: checked
    };
    
    onChange(updatedInfo);
    
    // Sprawdź czy wszystkie wymagane checkboxy są zaznaczone
    const requiredCheckboxes = ['dataProcessingAccepted', 'terms1Accepted', 'terms2Accepted'];
    const uncheckedBoxes = requiredCheckboxes.filter(box => !updatedInfo[box]);
    
    if (uncheckedBoxes.length > 0) {
      setCheckboxErrors(prev => ({
        ...prev,
        ...uncheckedBoxes.reduce((acc, box) => ({
          ...acc,
          [box]: 'To pole jest wymagane'
        }), {})
      }));
      onValidityChange(false);
    } else {
      setCheckboxErrors({});
      onValidityChange(isFormValid(updatedInfo));
    }
  };

  const getFieldError = (fieldName: string): string | null => {
    if (!touchedFields.has(fieldName)) return null;
    const error = validationErrors.find(err => err.field === fieldName);
    return error ? error.message : null;
  };

  const isFormValid = (info) => {
    return (
      info.firstName?.trim() !== '' &&
      info.lastName?.trim() !== '' &&
      info.email?.trim() !== '' && 
      info.email?.includes('@') &&
      info.phone?.trim() !== '' &&
      info.dataProcessingAccepted === true &&
      info.terms1Accepted === true &&
      info.terms2Accepted === true
    );
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-800">Dane osobowe</h2>
        <p className="text-sm text-gray-600 mt-1">
          Wprowadź swoje dane kontaktowe potrzebne do rezerwacji
        </p>
      </div>

      <div className="space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label htmlFor="firstName" className="block text-sm font-medium text-gray-700 mb-1">
              Imię
            </label>
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <User className="h-5 w-5 text-gray-400" />
              </div>
              <input
                type="text"
                id="firstName"
                name="firstName"
                value={personalInfo.firstName}
                onChange={handleChange}
                onBlur={handleBlur}
                pattern="[A-Za-zĄąĆćĘęŁłŃńÓóŚśŹźŻż\s-]+"
                className={`pl-10 w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 ${
                  getFieldError('firstName') ? 'border-red-500' : ''
                }`}
                placeholder="Jan"
                required
              />
            </div>
            {getFieldError('firstName') && (
              <p className="mt-1 text-sm text-red-500">{getFieldError('firstName')}</p>
            )}
          </div>
          <div>
            <label htmlFor="lastName" className="block text-sm font-medium text-gray-700 mb-1">
              Nazwisko
            </label>
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <User className="h-5 w-5 text-gray-400" />
              </div>
              <input
                type="text"
                id="lastName"
                name="lastName"
                value={personalInfo.lastName}
                onChange={handleChange}
                onBlur={handleBlur}
                pattern="[A-Za-zĄąĆćĘęŁłŃńÓóŚśŹźŻż\s-]+"
                className={`pl-10 w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 ${
                  getFieldError('lastName') ? 'border-red-500' : ''
                }`}
                placeholder="Kowalski"
                required
              />
            </div>
            {getFieldError('lastName') && (
              <p className="mt-1 text-sm text-red-500">{getFieldError('lastName')}</p>
            )}
          </div>
        </div>

        <div>
          <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
            Email
          </label>
          <div className="relative">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <Mail className="h-5 w-5 text-gray-400" />
            </div>
            <input
              type="email"
              id="email"
              name="email"
              pattern="[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"
              value={personalInfo.email}
              onChange={handleChange}
              onBlur={handleBlur}
              className={`pl-10 w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 ${
                getFieldError('email') ? 'border-red-500' : ''
              }`}
              placeholder="jan.kowalski@example.com"
              required
            />
          </div>
        </div>
        {getFieldError('email') && (
          <p className="mt-1 text-sm text-red-500">{getFieldError('email')}</p>
        )}

        <div>
          <label htmlFor="phone" className="block text-sm font-medium text-gray-700 mb-1">
            Telefon
          </label>
          <div className="relative">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <Phone className="h-5 w-5 text-gray-400" />
            </div>
            <input
              type="tel"
              id="phone"
              name="phone"
              pattern="[0-9]{9}"
              maxLength={11}
              inputMode="numeric"
              value={personalInfo.phone}
              onBlur={handleBlur}
              onChange={handleChange}
              className={`pl-10 w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 ${
                getFieldError('phone') ? 'border-red-500' : ''
              }`}
              placeholder="123 456 789"
              required
            />
          </div>
          {getFieldError('phone') && (
            <p className="mt-1 text-sm text-red-500">{getFieldError('phone')}</p>
          )}
        </div>

        <div>
          <label htmlFor="comment" className="block text-sm font-medium text-gray-700 mb-1">
            Opcjonalny komentarz
          </label>
          <textarea
            id="comment"
            name="comment"
            maxLength={500}
            value={personalInfo.comment || ''}
            onChange={handleChange}
            rows={3}
            className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Dodatkowe informacje lub uwagi do rezerwacji (max 500 znaków)..."
          />
        </div>

        {/* Company Data Section */}
        <div className="mt-8">
          <button
            type="button"
            onClick={() => setShowCompanyData(!showCompanyData)}
            className="w-full flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <span className="font-medium text-gray-700">Dane firmy (opcjonalne)</span>
            <ChevronDown className={`w-5 h-5 text-gray-500 transition-transform ${showCompanyData ? 'rotate-180' : ''}`} />
          </button>

          <AnimatePresence>
            {showCompanyData && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                transition={{ duration: 0.3 }}
                className="overflow-hidden"
              >
                <div className="space-y-4 mt-4 p-4 bg-gray-50 rounded-lg">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Pełna nazwa firmy
                    </label>
                    <input
                      type="text"
                      name="companyName"
                      value={personalInfo.companyName || ''}
                      onChange={handleChange}
                      className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="Nazwa firmy"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      NIP
                    </label>
                    <input
                      type="text"
                      name="companyNip"
                      value={personalInfo.companyNip || ''}
                      onChange={handleChange}
                      onBlur={handleBlur}
                      className={`w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 ${
                        getFieldError('companyNip') ? 'border-red-500' : ''
                      }`}
                      placeholder="XXX-XXX-XX-XX"
                    />
                    {getFieldError('companyNip') && (
                      <p className="mt-1 text-sm text-red-500">{getFieldError('companyNip')}</p>
                    )}
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Ulica i numer
                    </label>
                    <input
                      type="text"
                      name="companyStreet"
                      value={personalInfo.companyStreet || ''}
                      onChange={handleChange}
                      className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="Ulica i numer"
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Kod pocztowy
                      </label>
                      <input
                        type="text"
                        name="companyPostalCode"
                        value={personalInfo.companyPostalCode || ''}
                        onChange={handleChange}
                        onBlur={handleBlur}
                        className={`w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 ${
                          getFieldError('companyPostalCode') ? 'border-red-500' : ''
                        }`}
                        placeholder="XX-XXX"
                      />
                      {getFieldError('companyPostalCode') && (
                        <p className="mt-1 text-sm text-red-500">{getFieldError('companyPostalCode')}</p>
                      )}
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Miasto
                      </label>
                      <input
                        type="text"
                        name="companyCity"
                        value={personalInfo.companyCity || ''}
                        onChange={handleChange}
                        className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                        placeholder="Miasto"
                      />
                    </div>
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        <div className="bg-blue-50 p-6 rounded-lg space-y-4">
          <div className="space-y-4">
            {/* Podstawowe informacje - zawsze widoczne */}
            <div>
              <h3 className="font-medium text-blue-800 mb-2">Informacje o przetwarzaniu danych</h3>
              <p className="text-sm text-blue-700">
                Administratorem Pani/Pana danych osobowych jest SOLRENT z siedzibą w Knurowie 44-190 ul. Jęczmienna 4. 
                Dane będą przetwarzane w celu realizacji usługi wynajmu sprzętu. Podanie danych jest dobrowolne, ale niezbędne 
                do świadczenia usługi.
              </p>
            </div>

            {/* Przycisk rozwijający */}
            <button
              onClick={() => setShowFullInfo(!showFullInfo)}
              className="text-sm font-medium text-blue-600 hover:text-blue-800 flex items-center gap-1"
            >
              {showFullInfo ? 'Zwiń szczegóły' : 'Rozwiń pełną informację'}
              <ChevronDown className={`w-4 h-4 transition-transform ${showFullInfo ? 'rotate-180' : ''}`} />
            </button>

            {/* Pełna treść - ukryta domyślnie */}
            <AnimatePresence>
              {showFullInfo && (
                <motion.div
                  initial={{ height: 0, opacity: 0 }}
                  animate={{ height: 'auto', opacity: 1 }}
                  exit={{ height: 0, opacity: 0 }}
                  transition={{ duration: 0.3 }}
                  className="overflow-hidden"
                >
                  <div className="space-y-4 pt-2">
                    <div>
                      <p className="text-sm text-blue-700">
                        Podstawą prawną przetwarzania podanych przez Panią/Pana danych osobowych jest art. 6 ust. 1 lit. a ROZPORZĄDZENIA PARLAMENTU 
                        EUROPEJSKIEGO I RADY (UE) 2016/679 z dnia 27 kwietnia 2016 r. w sprawie ochrony osób fizycznych w związku z przetwarzaniem 
                        danych osobowych i w sprawie swobodnego przepływu takich danych oraz uchylenia dyrektywy 95/46/WE (RODO).
                      </p>
                    </div>

                    <div>
                      <p className="text-sm text-blue-700">
                        Podane przez Panią/Pana dane osobowe będą przetwarzane do czasu wycofania zgody. Przysługuje Pani/Panu:
                      </p>
                      <ul className="list-disc pl-6 mt-2 text-sm text-blue-700">
                        <li>prawo dostępu do treści podanych danych osobowych</li>
                        <li>prawo do ich sprostowania, usunięcia lub ograniczenia przetwarzania</li>
                        <li>prawo do przenoszenia danych</li>
                        <li>prawo do cofnięcia zgody w dowolnym momencie bez wpływu na zgodność z prawem przetwarzania dokonanego przed jej cofnięciem</li>
                        <li>prawo do wniesienia skargi do organu nadzorczego w zakresie ochrony danych osobowych</li>
                      </ul>
                    </div>

                    <div>
                      <p className="text-sm text-blue-700">
                        Pani/Pana dane osobowe nie będą przekazywane do państw trzecich, nie będą przetwarzane w sposób zautomatyzowany i nie będą profilowane.
                      </p>
                    </div>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </div>

        <div className="flex items-start space-x-2">
          <input
            id="dataProcessing"
            name="dataProcessingAccepted"
            type="checkbox"
            checked={personalInfo.dataProcessingAccepted || false}
            onChange={handleTermsChange}
            className="h-4 w-4 mt-1 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
          />
          <label htmlFor="dataProcessing" className="text-sm text-gray-700">
            <span className={checkboxErrors.dataProcessingAccepted ? 'text-red-600' : ''}>
              Oświadczam, że zapoznałem/-am się z powyższymi informacjami i wyrażam zgodę na przetwarzanie podanych przeze mnie danych osobowych we wskazanych powyżej celach i zakresie.
            </span>
          </label>
        </div>
        {checkboxErrors.dataProcessingAccepted && (
          <p className="mt-1 text-sm text-red-500">{checkboxErrors.dataProcessingAccepted}</p>
        )}

        <div className="space-y-4">
          <p className="font-medium text-gray-700">Oświadczam, że:</p>
          <div className="space-y-4">
            <div className="flex items-start">
              <input
                id="terms1"
                name="terms1Accepted"
                type="checkbox"
                checked={personalInfo.terms1Accepted || false}
                onChange={handleTermsChange}
                className={`h-4 w-4 mt-1 text-blue-600 focus:ring-blue-500 border-gray-300 rounded ${
                  checkboxErrors.terms1Accepted ? 'border-red-500' : ''
                }`}
              />
              <label htmlFor="terms1" className="ml-2 block text-sm text-gray-700">
                <span className={checkboxErrors.terms1Accepted ? 'text-red-600' : ''}>
                  Zapoznałem/am się z pełną treścią <a href="https://solrent.pl/zasady-wynajmu/" target="_blank" rel="noopener noreferrer" className="text-blue-600 hover:underline">Warunków Umowy Najmu</a> i akceptuję wszystkie jej postanowienia, w szczególności:
                </span>
                <ul className="list-disc pl-4 mt-1">
                  <li>Zasady korzystania ze sprzętu</li>
                  <li>Warunki płatności i rozliczeń</li>
                  <li>Możliwość potrącenia z wpłaconej kaucji w przypadkach określonych w Umowie</li>
                  <li>Odpowiedzialność za powierzony sprzęt</li>
                </ul>
              </label>
            </div>
            {checkboxErrors.terms1Accepted && (
              <p className="mt-1 text-sm text-red-500">{checkboxErrors.terms1Accepted}</p>
            )}

            <div className="flex items-start">
              <input
                id="terms2"
                name="terms2Accepted"
                type="checkbox"
                checked={personalInfo.terms2Accepted || false}
                onChange={handleTermsChange}
                className={`h-4 w-4 mt-1 text-blue-600 focus:ring-blue-500 border-gray-300 rounded ${
                  checkboxErrors.terms2Accepted ? 'border-red-500' : ''
                }`}
              />
              <label htmlFor="terms2" className="ml-2 block text-sm text-gray-700">
                <span className={checkboxErrors.terms2Accepted ? 'text-red-600' : ''}>
                  Przyjmuję do wiadomości i akceptuję zasady funkcjonowania wypożyczalni:
                </span>
                <div className="mt-1 pl-4">
                  <p className="font-medium">Godziny otwarcia (tylko w tych godzinach możliwy jest odbiór i zwrot sprzętu):</p>
                  <ul className="list-none mt-1">
                    <li>Poniedziałek - Piątek: 8:00 - 16:00</li>
                    <li>Sobota: 8:00 - 13:00</li>
                    <li>Niedziela: nieczynne</li>
                  </ul>
                </div>
                <div className="mt-2 pl-4">
                  <p className="font-medium">Wypożyczalnia zastrzega sobie prawo do:</p>
                  <ul className="list-disc mt-1">
                    <li>Odwołania rezerwacji z powodu usterek technicznych</li>
                    <li>Odwołania rezerwacji w przypadku zdarzeń losowych</li>
                    <li>Odmowy wydania sprzętu osobom, które nie spełniają warunków określonych w regulaminie</li>
                  </ul>
                </div>
              </label>
            </div>
            {checkboxErrors.terms2Accepted && (
              <p className="mt-1 text-sm text-red-500">{checkboxErrors.terms2Accepted}</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default PersonalInfoForm;