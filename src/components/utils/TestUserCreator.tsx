import React, { useState } from 'react';
import { createTestUser } from '../../lib/auth';

const TestUserCreator: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('Test123456');
  const [isLoading, setIsLoading] = useState(false);
  const [message, setMessage] = useState<{ text: string; type: 'success' | 'error' } | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setMessage(null);
    setIsLoading(true);

    try {
      const success = await createTestUser(email, password);
      
      if (success) {
        setMessage({ 
          text: 'Użytkownik testowy został utworzony pomyślnie. Możesz teraz przetestować funkcję resetowania hasła.',
          type: 'success'
        });
        setEmail('');
        setPassword('Test123456');
      } else {
        setMessage({ 
          text: 'Nie udało się utworzyć użytkownika testowego. Sprawdź konsolę, aby uzyskać więcej informacji.',
          type: 'error'
        });
      }
    } catch (err) {
      setMessage({ 
        text: 'Wystąpił błąd podczas tworzenia użytkownika testowego.',
        type: 'error'
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="max-w-md mx-auto p-6 bg-white rounded-lg shadow-lg">
      <h2 className="text-2xl font-bold mb-4">Utwórz użytkownika testowego</h2>
      <p className="text-gray-600 mb-4">
        Ten formularz służy do tworzenia użytkowników testowych w celu testowania funkcji resetowania hasła.
      </p>
      
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label htmlFor="email" className="block text-sm font-medium text-gray-700">
            Adres email
          </label>
          <input
            type="email"
            id="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-solrent-orange focus:border-solrent-orange"
            placeholder="np. test@example.com"
            required
          />
        </div>
        
        <div>
          <label htmlFor="password" className="block text-sm font-medium text-gray-700">
            Hasło
          </label>
          <input
            type="password"
            id="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-solrent-orange focus:border-solrent-orange"
            placeholder="Hasło (min. 8 znaków, 1 wielka litera, 1 cyfra)"
            required
          />
          <p className="text-xs text-gray-500 mt-1">
            Domyślne hasło: Test123456
          </p>
        </div>
        
        {message && (
          <div className={`p-4 rounded-md ${message.type === 'success' ? 'bg-green-50 text-green-800' : 'bg-red-50 text-red-800'}`}>
            {message.text}
          </div>
        )}
        
        <button
          type="submit"
          disabled={isLoading}
          className={`w-full py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white ${
            isLoading ? 'bg-gray-400 cursor-not-allowed' : 'bg-solrent-orange hover:bg-orange-700'
          }`}
        >
          {isLoading ? 'Tworzenie...' : 'Utwórz użytkownika testowego'}
        </button>
      </form>
    </div>
  );
};

export default TestUserCreator; 